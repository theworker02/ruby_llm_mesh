# frozen_string_literal: true

module RubyLlmMesh
  module Rag
    # Lightweight text chunker with optional overlap for RAG pipelines.
    class Chunker
      DEFAULT_SIZE = 800
      DEFAULT_OVERLAP = 100

      def initialize(size: DEFAULT_SIZE, overlap: DEFAULT_OVERLAP, separator: /\n{2,}|\n|\s+/)
        raise ArgumentError, "overlap must be less than size" if overlap >= size

        @size = size
        @overlap = overlap
        @separator = separator
      end

      def chunk(text)
        return [] if text.nil? || text.strip.empty?

        paragraphs = text.to_s.split(@separator).map(&:strip).reject(&:empty?)
        chunks = []
        buffer = +""

        paragraphs.each do |piece|
          candidate = buffer.empty? ? piece : "#{buffer} #{piece}"
          if candidate.length <= @size
            buffer = candidate
          else
            chunks << buffer unless buffer.empty?
            buffer = overlap_tail(buffer)
            buffer = buffer.empty? ? piece : "#{buffer} #{piece}"
            while buffer.length > @size
              chunks << buffer[0, @size]
              buffer = overlap_tail(buffer[0, @size]) + buffer[@size..]
            end
          end
        end

        chunks << buffer unless buffer.empty?
        chunks
      end

      private

      def overlap_tail(text)
        return "" if @overlap.zero? || text.nil? || text.empty?

        text[[text.length - @overlap, 0].max..]
      end
    end
  end
end
