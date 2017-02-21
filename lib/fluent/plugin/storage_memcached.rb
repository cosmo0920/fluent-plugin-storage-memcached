require 'json'
require 'dalli'
require 'fluent/plugin/storage'

module Fluent
  module Plugin
    class MemcachedStorage < Storage
      Fluent::Plugin.register_storage('memcached', self)

      config_param :path, :string, default: nil
      config_param :host, :string, default: 'localhost'
      config_param :port, :integer, default: 11211
      config_param :namespace, :string, default: 'app_v1'
      config_param :compress, :bool, default: true
      config_param :username, :string, default: nil
      config_param :password, :string, default: nil, secret: true
      config_param :serializer, :enum, list: [:yajl, :json, :marshal], default: :yajl
      config_param :expires_in, :time, default: 0
      # Set persistent true by default
      config_set_default :persistent, true

      attr_reader :store # for test

      def initialize
        super

        @store = {}
      end

      def configure(conf)
        super

        unless @path
          if conf && !conf.arg.empty?
            @path = conf.arg
          else
            raise Fluent::ConfigError, "path or conf.arg for <storage> is required."
          end
        end

        @serializer = case @serializer
                     when :yajl
                       Yajl
                     when :json
                       JSON
                     when :marshal
                       Marshal
                     end

        options = {
          threadsafe: true,
          namespace: @namespace,
          compress: @compress,
          serializer: @serializer,
          expires_on: @expires_in,
        }
        options[:username] = @username if @username
        options[:password] = @password if @password

        @memcached = Dalli::Client.new("#{@host}:#{@port}", options)

        object = @memcached.get(@path)
        if object
          begin
            data = @serializer.load(object)
            raise Fluent::ConfigError, "Invalid contents (not object) in plugin memcached storage: '#{@path}'" unless data.is_a?(Hash) unless data.is_a?(Hash)
          rescue => e
            log.error "failed to read data from plugin memcached storage", path: @path, error: e
            raise Fluent::ConfigError, "Unexpected error: failed to read data from plugin memcached storage: '#{@path}'"
          end
        end
      end

      def multi_workers_ready?
        true
      end

      def persistent_always?
        true
      end

      def load
        begin
          json_string = @memcached.get(@path)
          json = @serializer.load(json_string)
          unless json.is_a?(Hash)
            log.error "broken content for plugin storage (Hash required: ignored)", type: json.class
            log.debug "broken content", content: json_string
            return
          end
          @store = json
        rescue => e
          log.error "failed to load data for plugin storage from memcached", path: @path, error: e
        end
      end

      def save
        begin
          json_string = @serializer.dump(@store)
          @memcached.set(@path, json_string)
        rescue => e
          log.error "failed to save data for plugin storage to memcached", path: @path, error: e
        end
      end

      def get(key)
        @store[key.to_s]
      end

      def fetch(key, defval)
        @store.fetch(key.to_s, defval)
      end

      def put(key, value)
        @store[key.to_s] = value
      end

      def delete(key)
        @store.delete(key.to_s)
      end

      def update(key, &block)
        @store[key.to_s] = block.call(@store[key.to_s])
      end
    end
  end
end
