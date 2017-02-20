# fluent-plugin-storage-memcached

[![Build Status](https://travis-ci.org/cosmo0920/fluent-plugin-storage-memcached.svg?branch=master)](https://travis-ci.org/cosmo0920/fluent-plugin-storage-memcached)

fluent-plugin-storage-memcached is a fluent plugin to store plugin state into memcached.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-storage-memcached'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-storage-memcached

## Configuration

```aconf
<storage>
  @type memcached

  path my_key # or conf.arg will be used as memcached key
  host localhost     # localhost is default
  port 11211         # 11211 is default
  namespace app_v1   # app_v1 is default
  compress true      # true is default
  # If sasl enabled memcached server is configured, please specify them.
  # username fluenter
  # password hogefuga
  serializer yajl    # yajl is default
  expires_in 0       # 0 is default
</storage>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cosmo0920/fluent-plugin-storage-memcached.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
