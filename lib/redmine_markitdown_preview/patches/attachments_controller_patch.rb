# frozen_string_literal: true

module RedmineMarkitdownPreview
  module Patches
    module AttachmentsControllerPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods
      end

      module InstanceOverwriteMethods
        def show
          if markitdown_preview_response?
            return
          end

          super
        end

        private

        def markitdown_preview_response?
          return false unless request.get?
          return false unless @attachment
          return false unless @attachment.markitdown_previewable?

          content = @attachment.markitdown_preview_content
          return false unless content

          prepare_markitdown_pagination
          @content = content

          render :action => 'markitdown'

          true
        end

        def prepare_markitdown_pagination
          container = @attachment.container
          return unless container.respond_to?(:attachments)

          @attachments = container.attachments.to_a
          index = @attachments.index(@attachment)
          return if index.nil?

          @paginator = Redmine::Pagination::Paginator.new(@attachments.size, 1, index + 1)
        end
      end
    end
  end
end
