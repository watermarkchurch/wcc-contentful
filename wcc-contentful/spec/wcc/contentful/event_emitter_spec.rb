# frozen_string_literal: true

require 'wcc/contentful/event_emitter'

RSpec.describe WCC::Contentful::EventEmitter do
  class UUT
    include WCC::Contentful::EventEmitter
  end

  let(:subject) { UUT.new }

  describe '#add_listener' do
    it 'adds a proc' do
      count = 0
      id = subject.add_listener('test', proc { count += 1 })
      subject.emit('test')

      expect(id).to be_present
      expect(subject.has_listeners?).to be true
      expect(count).to eq(1)
    end
  end

  describe '#remove_listener' do
    it 'removes a proc by ID' do
      count = 0
      id = subject.add_listener('test', proc { count += 1 })

      subject.remove_listener(id)

      subject.emit('test')
      expect(count).to eq(0)
      expect(subject.has_listeners?).to be false
    end
  end

  describe '#emit' do
    it 'calls only listeners for given event' do
      expected = 0
      unexpected = 0
      subject.add_listener('test', proc { expected += 1 })
      subject.add_listener('other', proc { unexpected += 1 })
      subject.add_listener('test', proc { expected += 1 })

      subject.emit('test')

      expect(expected).to eq(2)
      expect(unexpected).to eq(0)
    end

    it 'passes arguments to procs' do
      calls = []
      subject.add_listener('test', ->(a, b) { calls << [a, b] })

      subject.emit('test', 1, 2)
      subject.emit('test', 3, 4)

      expect(calls[0]).to eq([1, 2])
      expect(calls[1]).to eq([3, 4])
    end

    it 'continues if a listener fails' do
      calls = []
      subject.add_listener('test', ->(a) { calls << [a] })
      subject.add_listener('test', ->(a, b) { calls << [a, b] })

      subject.emit('test', 1, 2)

      expect(calls.count).to eq(1)
      expect(calls[0]).to eq([1, 2])
    end
  end

  describe '#on' do
    it 'adds a block' do
      count = 0
      id = subject.on('test') { count += 1 }
      subject.emit('test')

      expect(id).to be_present
      expect(count).to eq(1)
    end

    it 'adds a proc' do
      count = 0
      id = subject.on('test', proc { count += 1 })
      subject.emit('test')

      expect(id).to be_present
      expect(count).to eq(1)
    end
  end

  describe '#once' do
    it 'removes the listener after receiving the first message' do
      count = 0
      id = subject.once('test') { count += 1 }

      expect(id).to be_present
      expect(subject.has_listeners?).to be true

      subject.emit('test')
      expect(subject.has_listeners?).to be false
      subject.emit('test')
      expect(count).to eq(1)
    end

    it 'passes arguments to the block' do
      emitted = []
      subject.once('test') { |arg| emitted << arg }

      subject.emit('test', 1)
      subject.emit('test', 2)

      expect(emitted).to eq([1])
    end

    it 'passes arguments to the proc' do
      emitted = []
      subject.once('test', ->(arg) { emitted << arg })

      subject.emit('test', 1)
      subject.emit('test', 2)

      expect(emitted).to eq([1])
    end

    it 'removes listener even if error thrown' do
      count = 0
      subject.once('test') {
        count += 1
        raise StandardError, 'Test Error'
      }

      subject.emit('test')
      subject.emit('test')

      expect(count).to eq(1)
    end

    it 'does not prevent other listeners from getting the message' do
      count = 0
      subject.on('test') { count += 1 }
      subject.once('test') { count += 1 }
      subject.on('test') { count += 1 }

      subject.emit('test')
      subject.emit('test')

      expect(count).to eq(5)
    end
  end
end
