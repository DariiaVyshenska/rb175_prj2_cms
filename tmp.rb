file_name_error

def error_unique_name(new_file_name, current_file_name)
  if other_file_names(curr_file_name).include?(new_file_name)
    "#{new_file_name} already exists. Please, use a unique name."
  end
end

def error_basename(basename)
  if basename.empty?
    'A name is reuired.'
  end
end

def error_extension(ext)
  supported_exts = Doc::ALLOWED_EXTENSIONS + Image::ALLOWED_EXTENSIONS
  unless supported_exts.include?(ext)
    "Allowed file extensions are: #{supported_exts.join(', ')}."
  end
end
