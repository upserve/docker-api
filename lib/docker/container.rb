# This class represents a Docker Container. It's important to note that nothing
# is cached so that the information is always up to date.
class Docker::Container
  include Docker::Model

  resource_prefix '/containers'

  create_request do |body|
    response = self.connection.post(
      :path    => '/containers/create',
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => "Docker-Client/0.4.6" },
      :body    => body.to_json,
      :expects => (200..204)
    )
    @id = JSON.parse(response.body)['Id']
    self
  end

  # Export the Container as a .tgz.
  get :export
  # Get more information about the Container.
  get :json
  # Wait for the current command to finish executing.
  post :wait
  # Start the Container.
  post :start
  # Inspect the Container's changes to the filesysetem
  get :changes
  # Stop the Container.
  post :stop
  # Kill the Container.
  post :kill
  # Restart the Container
  post :restart

  # Attach to a container's standard streams / logs.
  def attach(options = {})
    options = { :stream => true, :stdout => true }.merge(options)
    self.connection.post(
      :path    => "/containers/#{self.id}/attach",
      :headers => { 'Content-Type' => 'text/plain',
                    'User-Agent' => "Docker-Client/0.4.6" },
      :query   => options,
      :expects => (200..204)
    ).body
  end

  # Create an Image from a Container's change.s
  def commit(options = {})
    options.merge!('container' => self.id[0..7])
    hash = self.connection.json_request(:post, '/commit', options)
    Docker::Image.send(:new, :id => hash['Id'], :connection => self.connection)
  end
end
