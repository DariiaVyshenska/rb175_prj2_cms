# frozen_string_literal: true

require 'redcarpet'

# class that represents a generic file that can be uploaded &
# manipulated on the web-site.
class MyWebFile
  attr_writer :absolute_path

  def initialize(abs_path = nil)
    @absolute_path = abs_path
  end

  def self.create(path, content = nil)
    File.open(path, 'w') do |file|
      file.write(content)
    end
  end

  def name
    File.basename(absolute_path)
  end

  def absolute_path
    @absolute_path.clone
  end

  def rename(new_name)
    full_new_name = new_name + extension
    File.rename(absolute_path, new_abs_path(full_new_name))
    self.absolute_path = new_abs_path(full_new_name)
  end

  def duplicate
    copy_file_name = "copy_#{name}"
    self.class.create(new_abs_path(copy_file_name), content)
  end

  def delete
    File.delete(absolute_path)
    self.absolute_path = nil
  end

  def extensions_match?(other)
    extension == extension(other)
  end

  def extension(str = nil)
    str ||= name
    File.extname(str)
  end

  def basename
    name.chomp(extension)
  end

  def content
    File.read(absolute_path)
  end

  protected

  def new_abs_path(new_name)
    absolute_path.sub(name, new_name)
  end
end

# class represents document files
class Doc < MyWebFile
  ALLOWED_EXTENSIONS = %w[.txt .md].freeze

  def read
    case extension
    when '.md'
      render_md
    when '.txt'
      content
    end
  end

  def content=(new_content)
    File.open(absolute_path, 'w') do |file|
      file.write(new_content)
    end
  end

  private

  def render_md
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(content)
  end
end

# class represents images
class Image < MyWebFile
  ALLOWED_EXTENSIONS = %w[.jpg .png].freeze

  def self.upload(path, file)
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end
  end

  def relative_path
    curr_dir = "#{File.expand_path(__dir__)}/public/"
    absolute_path.sub(curr_dir, '')
  end
end
