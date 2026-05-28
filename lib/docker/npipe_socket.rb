# frozen_string_literal: true

require 'ffi'

# Excon-compatible socket backed by a Windows named pipe. Used to talk to the
# Docker engine via npipe:////./pipe/docker_engine on Windows. Implements the
# subset of the Excon::Socket interface that Excon::Connection actually drives.
class Docker::NPipeSocket < Excon::Socket
  module Win32
    extend FFI::Library

    ffi_lib 'kernel32'
    ffi_convention :stdcall

    GENERIC_READ    = 0x80000000
    GENERIC_WRITE   = 0x40000000
    OPEN_EXISTING   = 3
    INVALID_HANDLE_VALUE = FFI::Pointer.new(-1).address

    ERROR_BROKEN_PIPE         = 109
    ERROR_PIPE_NOT_CONNECTED  = 233

    NMPWAIT_USE_DEFAULT_WAIT = 0

    attach_function :CreateFileA, [:string, :ulong, :ulong, :pointer, :ulong, :ulong, :pointer], :pointer, save_errno: true
    attach_function :ReadFile,    [:pointer, :pointer, :ulong, :pointer, :pointer], :int, save_errno: true
    attach_function :WriteFile,   [:pointer, :pointer, :ulong, :pointer, :pointer], :int, save_errno: true
    attach_function :CloseHandle, [:pointer], :int
    attach_function :WaitNamedPipeA, [:string, :ulong], :int, save_errno: true
  end

  def initialize(data = {})
    # Windows named pipe IO from Ruby doesn't behave well in non-blocking mode,
    # so always use the blocking read/write paths from Excon::Socket.
    super(data.merge(nonblock: false))
  end

  def read(max_length = nil)
    return '' if @eof && max_length.nil?
    return nil if @eof

    buffer_size = max_length || @data[:chunk_size] || 16_384
    buf = FFI::MemoryPointer.new(:char, buffer_size)
    bytes_read = FFI::MemoryPointer.new(:ulong)

    result = with_timeout(:read_timeout) do
      Win32.ReadFile(@handle, buf, buffer_size, bytes_read, nil)
    end

    n = bytes_read.read_ulong
    if result == 0
      err = FFI.errno
      if err == Win32::ERROR_BROKEN_PIPE || err == Win32::ERROR_PIPE_NOT_CONNECTED
        @eof = true
        return max_length ? nil : ''
      end
      raise Excon::Errors::SocketError.new(IOError.new("ReadFile failed (err=#{err})"))
    end

    if n.zero?
      @eof = true
      return max_length ? nil : ''
    end

    buf.read_string(n)
  end

  def readline
    line = String.new
    until (idx = line.index("\n"))
      chunk = read(1)
      raise EOFError if chunk.nil? || chunk.empty?
      line << chunk
    end
    line
  end

  def write(data)
    data = data.b
    offset = 0
    total = data.bytesize
    written_out = FFI::MemoryPointer.new(:ulong)
    buf = FFI::MemoryPointer.new(:char, total)
    buf.write_string(data)

    while offset < total
      result = with_timeout(:write_timeout) do
        Win32.WriteFile(
          @handle,
          buf + offset,
          total - offset,
          written_out,
          nil
        )
      end

      if result == 0
        err = FFI.errno
        raise Excon::Errors::SocketError.new(IOError.new("WriteFile failed (err=#{err})"))
      end

      n = written_out.read_ulong
      raise Excon::Errors::SocketError.new(IOError.new('WriteFile wrote 0 bytes')) if n.zero?
      offset += n
    end

    total
  end

  def close
    return if @handle.nil? || @handle.address == Win32::INVALID_HANDLE_VALUE
    Win32.CloseHandle(@handle)
    @handle = nil
  end

  def local_address
    nil
  end

  def local_port
    nil
  end

  private

  def connect
    pipe_path = self.class.normalize_pipe_path(@data[:socket] || @data[:path])
    raise ArgumentError, 'npipe socket requires a pipe path' if pipe_path.nil? || pipe_path.empty?

    # Wait for the pipe to be available if a previous connection holds it.
    Win32.WaitNamedPipeA(pipe_path, Win32::NMPWAIT_USE_DEFAULT_WAIT)

    @handle = Win32.CreateFileA(
      pipe_path,
      Win32::GENERIC_READ | Win32::GENERIC_WRITE,
      0,
      nil,
      Win32::OPEN_EXISTING,
      0,
      nil
    )

    if @handle.nil? || @handle.address == Win32::INVALID_HANDLE_VALUE
      err = FFI.errno
      raise Excon::Errors::SocketError.new(
        IOError.new("Could not open npipe '#{pipe_path}' (err=#{err})")
      )
    end
  end

  def with_timeout(kind)
    timeout = @data[kind]
    return yield if timeout.nil? || timeout.zero?

    Timeout.timeout(timeout) { yield }
  rescue Timeout::Error
    raise Excon::Errors::Timeout.new("#{kind} reached")
  end

  # Accepts any of: '\\.\pipe\docker_engine', '//./pipe/docker_engine',
  # '////./pipe/docker_engine', '/pipe/docker_engine'. Returns the canonical
  # Windows form '\\.\pipe\<name>'.
  def self.normalize_pipe_path(path)
    return nil if path.nil? || path.empty?

    path = path.tr('/', "\\")
    path = path.sub(/\A\\+/, '')   # drop any leading backslashes
    path = path.sub(/\A\.\\/, '')  # drop leading ".\" if present
    "\\\\.\\#{path}"
  end
end
