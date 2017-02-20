require_relative '../helper'
require 'fluent/test/helpers'
require 'fluent/plugin/storage_memcached'
require 'fluent/plugin/input'

class MemcachedStorageTest < Test::Unit::TestCase
  include Fluent::Test::Helpers

  class MyInput < Fluent::Plugin::Input
    helpers :storage
    config_section :storage do
      config_set_default :@type, 'memcached'
    end
  end

  def host
    "localhost"
  end

  def port
    11211
  end

  def setup_memcached
    @store = {}
    options = {
      thread_safe: true,
      namespace: "app_v1",
      compress: true,
      serializer: JSON,
      expires_on: 0,
    }

    @memcached = Dalli::Client.new("#{host}:#{port}", options)
  end

  def teardown_memcached
    @memcached.flush_all if @memcached
  end

  setup do
    Fluent::Test.setup
    @d = MyInput.new
    setup_memcached
    @path = 'my_store_key'
  end

  teardown do
    @d.stop unless @d.stopped?
    @d.before_shutdown unless @d.before_shutdown?
    @d.shutdown unless @d.shutdown?
    @d.after_shutdown unless @d.after_shutdown?
    @d.close unless @d.closed?
    @d.terminate unless @d.terminated?
    teardown_memcached
  end


  sub_test_case 'without any configuration' do
    test 'raise Fluent::ConfigError' do
      conf = config_element()

      assert_raise(Fluent::ConfigError) do
        @d.configure(conf)
      end
    end
  end

  sub_test_case '#configure' do
    test "default" do
      storage_path = @path
      conf = config_element('ROOT', '', {}, [config_element('storage', '', {
                                                              'path' => storage_path,
                                                            }
                                                           )])
      @d.configure(conf)
      @d.start
      @p = @d.storage_create()
      assert_true(@p.persistent)

      assert_equal('my_store_key', @p.path)
      assert_equal(host, @p.host)
      assert_equal(port, @p.port)
      assert_equal("app_v1", @p.namespace)
      assert_true(@p.compress)
      assert_nil(@p.username)
      assert_nil(@p.password)
      assert_equal(Yajl, @p.serializer)
      assert_equal(0, @p.expires_in)
    end
  end

  sub_test_case 'configured with path key' do
    data(
      "yajl" => :yajl,
      "json" => :json,
      "marshal" => :marshal,
    )
    test 'configured with several serializers' do |data|
      serializer = data
      storage_path = @path
      conf = config_element('ROOT', '', {}, [config_element('storage', '', {
                                                              'path' => storage_path,
                                                              'serializer' => serializer,
                                                            })])
      @d.configure(conf)
      @d.start
      @p = @d.storage_create()
      assert_true(@p.persistent)

      assert_equal storage_path, @p.path
      assert @p.store.empty?

      assert_nil @p.get('key1')
      assert_equal 'EMPTY', @p.fetch('key1', 'EMPTY')

      @p.put('key1', '1')
      assert_equal '1', @p.get('key1')

      @p.update('key1') do |v|
        (v.to_i * 2).to_s
      end
      assert_equal '2', @p.get('key1')

      @p.save # stores all data into redis

      assert @p.load

      @p.put('key2', 4)

      @d.stop; @d.before_shutdown; @d.shutdown; @d.after_shutdown; @d.close; @d.terminate

      assert_equal({'key1' => '2', 'key2' => 4}, @p.load)

      # re-create to reload storage contents
      @d = MyInput.new
      @d.configure(conf)
      @d.start
      @p = @d.storage_create()

      assert_false @p.store.empty?

      assert_equal '2', @p.get('key1')
      assert_equal 4, @p.get('key2')
    end
  end

  sub_test_case 'configured with conf.arg' do
    test 'works with customized path key by specified usage' do
      storage_conf = {}
      conf = config_element('ROOT', '', {}, [config_element('storage', "#{@path}", storage_conf)])
      @d.configure(conf)
      @d.start
      @p = @d.storage_create(usage: "#{@path}")
      assert_true(@p.persistent)

      assert_equal @path, @p.path
      assert @p.store.empty?

      @p.put('key1', '1')
      assert_equal '1', @p.get('key1')

      @p.save # stores all data into redis

      assert_equal({"key1"=>"1"}, @p.load)
    end
  end
end
