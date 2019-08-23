require 'coveralls'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  root __dir__
  add_filter %r{^spec/}
end

