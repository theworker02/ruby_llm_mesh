# frozen_string_literal: true

require_relative "test_helper"

class EmbeddingsTest < Minitest::Test
  def setup
    super
    @embedder = RubyLlmMesh::Rag::Embeddings.new(dimensions: 64)
  end

  def test_embed_returns_normalized_vector
    vec = @embedder.embed("ruby mesh routing")
    assert_equal 64, vec.length
    norm = Math.sqrt(vec.sum { |v| v * v })
    assert_in_delta 1.0, norm, 0.0001
  end

  def test_identical_texts_are_similar
    a = @embedder.embed("circuit breaker pattern")
    b = @embedder.embed("circuit breaker pattern")
    assert_in_delta 1.0, @embedder.cosine_similarity(a, b), 0.0001
  end

  def test_top_k
    docs = [
      "refund billing invoice",
      "weather in paris",
      "billing customer refund policy"
    ]
    hits = @embedder.top_k("refund billing", docs, k: 2)
    assert_equal 2, hits.length
    assert hits.first[:score] >= hits.last[:score]
    assert_match(/billing|refund/, hits.first[:document])
  end

  def test_embed_many
    vectors = @embedder.embed_many(%w[one two])
    assert_equal 2, vectors.length
  end
end
