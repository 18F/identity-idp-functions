require 'spec_helper'

RSpec.describe IdentityIdpFunctions::LoggingHelper do
  let(:io) { StringIO.new }

  subject(:instance) do
    klass = Class.new do
      include IdentityIdpFunctions::LoggingHelper
    end

    klass.new.tap do |instance|
      instance.logger(io: io)
    end
  end

  describe '#log_event' do
    it 'logs a named event as JSON' do
      instance.log_event(name: 'foobar')

      json = JSON.parse(io.string, symbolize_names: true)
      expect(json[:name]).to eq('foobar')
    end

    it 'logs extra keyword arguments in JSON' do
      instance.log_event(name: 'foobar', count: 1, color: 'red')

      json = JSON.parse(io.string, symbolize_names: true)
      expect(json[:count]).to eq(1)
      expect(json[:color]).to eq('red')
    end

    it 'can accept a different log level' do
      instance.log_event(level: :warn, name: 'foobar')
      instance.log_event(level: Logger::WARN, name: 'foobar')

      io.string.lines.each do |line|
        json = JSON.parse(line, symbolize_names: true)
        expect(json[:level]).to eq('WARN')
      end
    end
  end

  describe '#logger' do
    it 'merges hashes in to the payload' do
      instance.logger.info(foobar: true)

      json = JSON.parse(io.string, symbolize_names: true)
      expect(json[:foobar]).to eq(true)
    end

    it 'turns strings into a message key' do
      instance.logger.info('string')

      json = JSON.parse(io.string, symbolize_names: true)
      expect(json[:message]).to eq('string')
    end

    it 'logs the time as an ISO8601' do
      instance.logger.warn('now')

      json = JSON.parse(io.string, symbolize_names: true)
      expect(Time.parse(json[:time]).to_i).to be_within(2).of(Time.now.to_i)
    end

    it 'logs the level' do
      instance.logger.fatal('now')

      json = JSON.parse(io.string, symbolize_names: true)
      expect(json[:level]).to eq('FATAL')
    end
  end
end
