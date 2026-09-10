# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'tempfile'
require 'timeout'

module RedmineMarkitdownPreview
  module Converter
    extend Redmine::Utils::Shell

    def self.supports?(filename)
      supported_extensions.include?(File.extname(filename.to_s).downcase)
    end

    def self.convert(source, target)
      return nil unless available?
      return target if File.file?(target)
      return nil unless File.file?(source)

      source_size = File.size(source)

      if source_too_large?(source_size)
        logger.warn("MarkItDown preview generation skipped because source file is too large (#{source_size} bytes): #{source}")
        return nil
      end

      FileUtils.mkdir_p(File.dirname(target))

      args = command_arguments + [source.to_s]
      pid = nil
      output = Tempfile.new('markitdown-preview')
      error_output = Tempfile.new('markitdown-preview-error')

      begin
        Timeout.timeout(preview_generation_timeout) do
          pid = Process.spawn(*args, out: output.path, err: error_output.path, pgroup: true)
          _waited_pid, status = Process.wait2(pid)
          pid = nil

          unless status.success?
            error_output.rewind
            logger.error("MarkItDown preview generation failed \n(#{status.exitstatus}):\nCommand: #{args.shelljoin}\n#{error_output.read}")
            return nil
          end
        end

        preview = File.binread(output.path, maximum_output_size + 1)
        File.binwrite(target, preview.byteslice(0, maximum_output_size))

        target
      rescue Timeout::Error
        terminate_process_group(pid)
        logger.error("MarkItDown preview generation timed out:\nCommand: #{args.shelljoin}")

        nil
      rescue StandardError => e
        terminate_process_group(pid)
        logger.error("MarkItDown preview generation failed:\nCommand: #{args.shelljoin}\nException was: #{e.class}: #{e.message}")

        nil
      ensure
        output.close!
        error_output.close!
      end
    end

    def self.available?
      return @available if defined?(@available)

      _pid, status = Process.wait2(
        Process.spawn(*command_arguments, '--version', out: File::NULL, err: File::NULL)
      )

      @available = status.success?
    rescue SystemCallError, IOError
      @available = false
    ensure
      unless @available
        logger.warn("MarkItDown converter command (#{command}) not available")
      end
    end

    def self.logger
      Rails.logger
    end

    def self.reset_settings_cache!
      [
        :@available,
        :@command,
        :@preview_generation_timeout,
        :@maximum_source_size,
        :@maximum_output_size,
        :@supported_extensions
      ].each do |variable|
        remove_instance_variable(variable) if instance_variable_defined?(variable)
      end
    end

    def self.command
      @command ||= RedmineMarkitdownPreview.safe_setting('markitdown_command').presence || 'markitdown'
    end

    def self.command_arguments
      Shellwords.split(command)
    end
    private_class_method :command_arguments

    def self.preview_generation_timeout
      @preview_generation_timeout ||= begin
        value = RedmineMarkitdownPreview.safe_setting(
          'markitdown_preview_generation_timeout'
        ).to_i

        value.positive? ? value : 10
      end
    end

    def self.maximum_output_size
      @maximum_output_size ||= begin
        value = RedmineMarkitdownPreview.safe_setting(
          'markitdown_preview_max_output_size'
        ).to_i

        value.positive? ? value : 100.kilobytes
      end
    end

    def self.maximum_source_size
      @maximum_source_size ||= RedmineMarkitdownPreview.safe_setting(
        'markitdown_preview_max_source_size'
      ).to_i
    end

    def self.supported_extensions
      @supported_extensions ||= RedmineMarkitdownPreview
              .safe_setting_array('markitdown_supported_extensions')
              .map(&:downcase)
              .freeze
    end

    def self.source_too_large?(source_size)
      maximum_source_size.positive? && source_size > maximum_source_size
    end
    private_class_method :source_too_large?

    def self.terminate_process_group(pid)
      return unless pid

      Process.kill('KILL', -pid)
      Process.wait(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
    private_class_method :terminate_process_group
  end
end
