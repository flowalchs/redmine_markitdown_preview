# frozen_string_literal: true

require 'fileutils'

module RedmineMarkitdownPreview
  module Patches
    module AttachmentPatch
      extend ActiveSupport::Concern

      included do
        prepend InstanceOverwriteMethods

        after_commit :delete_markitdown_preview, on: :destroy
      end
      module InstanceOverwriteMethods

        def markitdown_previewable?
          readable? && RedmineMarkitdownPreview::Converter.available? && RedmineMarkitdownPreview::Converter.supports?(filename)
        end

        def markitdown_preview_content
          return nil unless markitdown_previewable?

          target = markitdown_preview_cache_path

          if RedmineMarkitdownPreview::Converter.convert(diskfile, target)
            File.binread(target)
          end
        rescue StandardError => e
          Rails.logger.error("An error occurred while generating MarkItDown preview for #{disk_filename} to #{target}: #{e.class}: #{e.message}")

          nil
        end

        def markitdown_preview_cache_path
          File.join(RedmineMarkitdownPreview.preview_storage_path, "#{digest}_#{filesize}.md")
        end

        private

        def delete_markitdown_preview
          FileUtils.rm_f(markitdown_preview_cache_path)
        rescue StandardError => e
          Rails.logger.error("Could not remove MarkItDown preview for #{disk_filename}: #{e.message}")
        end
        
      end
    end
  end
end