# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/content_for'
require 'yaml'
require 'bcrypt'

require_relative 'mywebfile'

configure do
  enable :sessions
  set :session_secret, 'some_secre1_of=mine'
  set :erb, escape_html: true
end

helpers do
  def logged_in?
    session.key?(:login)
  end
end

def redirect_if_logout
  return if logged_in?

  session[:msg] = 'You must be signed in to do that.'
  redirect '/'
end

def docs_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('test/data', __dir__)
  else
    File.expand_path('data', __dir__)
  end
end

def images_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('test/public/images', __dir__)
  else
    File.expand_path('public/images', __dir__)
  end
end

def user_info_path
  root = if ENV['RACK_ENV'] == 'test'
           File.expand_path('test', __dir__)
         else
           File.expand_path(__dir__)
         end
  File.join(root, 'users.yml')
end

def user_info
  YAML.load_file(user_info_path)
end

def existing_docs
  Dir.glob(File.join(docs_path, '*')).map do |path|
    Doc.new(path)
  end
end

def existing_images
  Dir.glob(File.join(images_path, '*')).map do |path|
    Image.new(path)
  end
end

def valid_credentials?
  user_pw = user_info[params[:username]]
  BCrypt::Password.new(user_pw) == params[:password] if user_pw
end

def error_new_credentials(name, pass1, pass2)
  if name.empty?
    'You must enter a new username.'
  elsif user_info[name]
    'This username already exists. Pick another one!'
  elsif pass1 != pass2
    'Entered passwords do not match.'
  elsif pass1.size < 4
    'The password must be 5 or more characters.'
  end
end

def error_unique_name(new_file_name, current_file_name = nil)
  return unless other_file_names(current_file_name).include?(new_file_name)

  "#{new_file_name} already exists. Please, use a unique name."
end

def error_basename(basename)
  'A name is required.' if basename.empty?
end

def error_extension(ext, type)
  supported_exts = case type
                   when 'doc' then Doc::ALLOWED_EXTENSIONS
                   when 'img' then Image::ALLOWED_EXTENSIONS
                   end

  "Allowed file extensions are: #{supported_exts.join(', ')}." unless supported_exts.include?(ext)
end

def other_file_names(current_file_name = nil)
  all_f_names = existing_docs.concat(existing_images).map(&:name)
  return all_f_names unless current_file_name

  all_f_names.reject { |el| el == current_file_name }
end

def check_path(path)
  return if File.exist?(path)

  session[:msg] = 'File does not exist.'
  redirect '/'
end

def update_user_info(username, pass)
  updated_user_info = user_info
  updated_user_info[username] = BCrypt::Password.create(pass).to_s
  File.open(user_info_path, 'w') { |file| YAML.dump(updated_user_info, file) }
end

def login
  session[:login] = params[:username].strip
end

def cleaned_filename
  File.basename(params[:file_name].strip)
end

def img_path
  File.join(images_path, cleaned_filename)
end

def doc_path
  File.join(docs_path, cleaned_filename)
end

def new_basename
  params[:new_basename].strip.gsub(/[^0-9a-z_\-. ]/i, '')
end
#===============================================================================
# ++++ MAIN PAGE
get '/' do
  @docs = existing_docs
  @images = existing_images
  erb :index
end

# ++++ Sign-in & Sign-out

get '/signup' do
  redirect '/' if logged_in?
  erb :signup
end

post '/signup' do
  redirect '/' if logged_in?

  username = params[:username].strip
  pass1 = params[:password1]
  pass2 = params[:password2]

  error = error_new_credentials(username, pass1, pass2)
  if error
    session[:msg] = error
    status 422
    erb :signup
  else
    update_user_info(username, pass1)
    login
    session[:msg] = 'Your accout has been successfully created.'
    redirect '/'
  end
end

get '/users/signin' do
  erb :signin
end

post '/signin' do
  if valid_credentials?
    login
    session[:msg] = "Welcome, #{session[:login]}!"
    redirect '/'
  else
    session[:msg] = 'Invalid Credentials'
    status 422
    erb :signin
  end
end

post '/signout' do
  session.delete(:login)
  session[:msg] = 'You have been signed out.'
  redirect '/'
end

# ++++ IMAGES
get '/images/:file_name/edit' do
  redirect_if_logout

  @img = Image.new(img_path)
  erb :edit_image
end

post '/images/:file_name/edit' do
  redirect_if_logout

  @img = Image.new(img_path)
  full_new_name = new_basename + @img.extension

  error = error_basename(new_basename) || error_unique_name(full_new_name, @img.name)
  if error
    status 422
    session[:msg] = error
    erb :edit_image
  else
    session[:msg] = "#{@img.name} has been updated."
    @img.rename(new_basename)
    redirect '/'
  end
end

post '/images/:file_name/delete' do
  redirect_if_logout

  Image.new(img_path).delete
  session[:msg] = "#{params[:file_name]} was deleted."
  redirect '/'
end

post '/images/:file_name/duplicate' do
  redirect_if_logout

  Image.new(img_path).duplicate
  session[:msg] = "#{params[:file_name]} was duplicated."
  redirect '/'
end

get '/images/new' do
  redirect_if_logout

  erb :image_upload
end

post '/images/new' do
  redirect_if_logout

  if params[:image] && params[:image][:filename]
    file_name = params[:image][:filename]
    upload_path = File.join(images_path, file_name)
    file = params[:image][:tempfile]

    error = error_extension(File.extname(file_name), 'img') || error_unique_name(file_name)
    if error
      session[:msg] = error
      erb :image_upload
    else
      Image.upload(upload_path, file)
      session[:msg] = "#{file_name} was uploaded."
      redirect '/'
    end
  else
    session[:msg] = 'Please, select a file for upload!'
    erb :image_upload
  end
end

get '/images/:file_name' do
  check_path(img_path)
  Image.new(img_path).read
end

# ++++ DOCS
get '/docs/:file_name/edit' do
  redirect_if_logout

  @doc = Doc.new(doc_path)
  erb :edit_file
end

post '/docs/:file_name/edit' do
  redirect_if_logout

  @doc = Doc.new(doc_path)
  new_full_name = new_basename + @doc.extension
  new_file_text = params[:new_file_text]
  error = error_basename(new_basename) || error_unique_name(new_full_name, @doc.name)
  if error
    session[:msg] = error
    status 422
    erb :edit_file
  else
    session[:msg] = "#{@doc.name} has been updated."
    @doc.rename(new_basename)
    @doc.content = new_file_text
    redirect '/'
  end
end

post '/docs/:file_name/delete' do
  redirect_if_logout

  Doc.new(doc_path).delete
  session[:msg] = "#{params[:file_name]} was deleted."
  redirect '/'
end

post '/docs/:file_name/duplicate' do
  redirect_if_logout

  Doc.new(doc_path).duplicate
  session[:msg] = "#{params[:file_name]} was duplicated."
  redirect '/'
end

get '/docs/new' do
  redirect_if_logout

  erb :new_doc
end

post '/docs/new' do
  redirect_if_logout

  new_ext = ".#{params[:new_extension].strip}"
  new_full_name = new_basename + new_ext

  error = error_basename(new_basename) || error_extension(new_ext, 'doc') || error_unique_name(new_full_name)
  if error
    status 422
    session[:msg] = error
    erb :new_doc
  else
    Doc.create(File.join(docs_path, new_full_name), params[:file_text])
    session[:msg] = "#{new_full_name} was created."
    redirect '/'
  end
end

get '/docs/:file_name' do
  check_path(doc_path)
  doc = Doc.new(doc_path)
  content = doc.read
  case doc.extension
  when '.txt'
    content_type 'text/plain'
    content
  when '.md'
    erb content
  end
end
