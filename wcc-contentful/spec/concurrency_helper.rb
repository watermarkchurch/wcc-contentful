# frozen_string_literal: true

require 'timeout'

module ConcurrencyHelper
  def do_in_threads(num_threads, timeout: 5, &block)
    wait_to_start = true
    threads =
      Array.new(num_threads).map do
        Thread.new do
          true while wait_to_start
          Timeout.timeout(timeout, &block)
        end
      end
    wait_to_start = false
    threads.map(&:value)
  end
end
