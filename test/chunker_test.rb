# frozen_string_literal: true

require_relative "test_helper"

class ChunkerTest < Minitest::Test
  def test_empty_text
    assert_equal [], RubyLlmMesh::Rag::Chunker.new.chunk("")
    assert_equal [], RubyLlmMesh::Rag::Chunker.new.chunk(nil)
  end

  def test_small_text_single_chunk
    text = "Hello world"
    chunks = RubyLlmMesh::Rag::Chunker.new(size: 100, overlap: 10).chunk(text)
    assert_equal 1, chunks.length
    assert_includes chunks.first, "Hello"
  end

  def test_splits_long_text
    text = ([ "word" ] * 200).join(" ")
    chunks = RubyLlmMesh::Rag::Chunker.new(size: 50, overlap: 10).chunk(text)
    assert chunks.length > 1
    chunks.each { |c| assert c.length <= 50 + 20 } # allow overlap assembly slack
  end

  def test_overlap_must_be_less_than_size
    assert_raises(ArgumentError) do
      RubyLlmMesh::Rag::Chunker.new(size: 10, overlap: 10)
    end
  end
end
