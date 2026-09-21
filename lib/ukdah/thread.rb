# frozen_string_literal: true

module Ukdah
  module Thread_
    class Node
      attr_accessor :parent
      attr_reader :message, :children

      def initialize(message = nil)
        @message = message
        @children = []
        @parent = nil
      end

      def id
        message && message.message_id
      end

      def placeholder?
        message.nil?
      end
    end

    module_function

    def build(messages)
      nodes = {}
      ordered = []
      Array(messages).each do |message|
        id = normalize(message.message_id)
        next if id.nil? || id.empty? || (nodes[id] && !nodes[id].placeholder?)

        node = nodes[id] || Node.new
        node.instance_variable_set(:@message, message)
        nodes[id] = node
        ordered << node unless ordered.include?(node)
      end

      Array(messages).each do |message|
        child = nodes[normalize(message.message_id)]
        next unless child

        parent = nil
        (Array(message.references) + Array(message.in_reply_to)).each do |reference|
          reference_id = normalize(reference)
          next if reference_id.nil? || reference_id.empty?

          candidate = nodes[reference_id] ||= Node.new
          ordered << candidate unless ordered.include?(candidate)
          parent = candidate
        end
        next unless parent && parent != child

        detach(child)
        child.parent = parent
        parent.children << child unless parent.children.include?(child)
      end

      ordered.select { |node| node.parent.nil? }
    end

    def normalize(id)
      id.to_s.strip.gsub(/\A<|>\z/, "").downcase unless id.nil?
    end

    def detach(node)
      return unless node.parent

      node.parent.children.delete(node)
      node.parent = nil
    end
  end
end
