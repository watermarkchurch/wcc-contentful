
# frozen_string_literal: true

module BenchHelper
  def build_store(store: nil, copies: 1)
    sync_initial = JSON.parse(load_fixture('contentful/sync_initial.json'))
    store ||= WCC::Contentful::Sync::MemoryStore.new

    sync_initial.each do |k, v|
      1.upto(copies) do |i|
        v = v.deep_dup
        if i > 1
          k += i.to_s
          v['sys']['id'] = k
        end
        store.index(k, v)
      end
    end
    WCC::Contentful::Model.store = store
  end

  def run_bench(content_type: nil, iterations: nil, copies: nil, before: nil)
    iterations ||= [1000, 10_000, 100_000]
    copies ||= [10, 100, 1000]

    Benchmark.benchmark(Benchmark::CAPTION, 35, Benchmark::FORMAT, '>avg:') do |x|
      times = []
      copies.each do |c|
        store = build_store(copies: c)
        all_ids =
          if content_type.nil?
            store.keys.shuffle
          else
            store.find_by(content_type: content_type).map { |i| i.dig('sys', 'id') }
          end
        before.call(store) if before.present?

        iterations.each do |n|
          if times.last.present? && (times.last.real * n) > (10 * 60)
            warn "Skipping iteration #{n} because it would take approx. " \
              "#{(times.last.real * n) / 60} minutes"
            next
          end

          time =
            x.report("#{store.find_all.count} entries - #{n} iterations") do
              n.times do |i|
                yield all_ids[i % all_ids.length], i, c
              end
            end

          times.push(time / n)
        end
      end
      [times.reduce(&:+) / times.count]
    end
  end
end
