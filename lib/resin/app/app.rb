require 'rubygems'
require 'sinatra/base'
require 'haml'

AMBER_PATH = File.expand_path('../../../../amber', __FILE__)

module Resin
  def env
    ENV['RACK_ENV']
  end
  module_function :env

  def development?
    !(env == 'production')
  end
  module_function :development?

  class Server < Sinatra::Base
    set :dump_errors, true
    set :views,  File.expand_path('../views', __FILE__)

    def javascript_files
      files = []
      Dir.glob("#{Dir.pwd}/js/*.js") do |filename|
        unless filename.include? 'deploy'
          files << "\"#{File.basename(filename)}\""
        end
      end
      files.join(',')
    end

    get '/' do
      haml :index
    end

    def load_resource(prefix, filename)
      # A file in our working directory will take precedence over the
      # Amber-bundled files. This should allow custom Kernel-Objects.js files
      # for example.
      local_file = File.join(Dir.pwd, "#{prefix}/", filename)
      amber_file = File.join(AMBER_PATH, "/#{prefix}/", filename)

      if File.exists? local_file
        File.open(local_file, 'r').read
      elsif File.exists? amber_file
        File.open(amber_file, 'r').read
      else
        nil
      end
    end

    def content_type_for_ext(filename)
      if File.extname(filename) == '.js'
        content_type 'application/javascript'
      elsif File.extname(filename) == '.css'
        content_type 'text/css'
      else
        content_type 'text/plain'
      end
    end

    ['js', 'css', 'images'].each do |path|
      get "/#{path}/*" do |filename|
        content_type_for_ext filename
        data = load_resource(path, filename)
        if data.nil?
          halt 404
        end
        data
      end
    end

    if Resin.development?
      set :logging, true
      disable :protection

      # Only enable the saving mechanism in test/development
      put '*' do
        puts "Trying #{request.path}"
        unless request.body.nil?
          path = File.join(Dir.pwd, request.path)
          puts ">> Commiting changes to #{path}"
          File.open(path, 'w') do |fd|
            request.body.each do |line|
              fd.write(line)
            end
          end
        end
      end
    end
  end
end
