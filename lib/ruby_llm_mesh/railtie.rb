# frozen_string_literal: true

module RubyLlmMesh
  class Railtie < ::Rails::Railtie
    initializer "ruby_llm_mesh.active_record" do
      ActiveSupport.on_load(:active_record) do
        require_relative "active_record/acts_as_ai_agent"
        extend RubyLlmMesh::ActiveRecord::ActsAsAiAgent
      end
    end
  end
end
