# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubi'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
end

helpers do
  def flash_message(name)
    return unless session[name]

    <<~MESSAGE
      <div class = "flash #{name}">
      <p>#{session.delete(name)}</p>
      </div>
    MESSAGE
  end

  def list_complete?(list)
    todos = list[:todos]
    todos.all? { |todo| todo[:completed] } && todos.size >= 1
  end

  def list_class(list)
    'class = complete' if list_complete?(list)
  end

  def todos_completed(list)
    todos = list[:todos]
    total_complete = todos.count { |todo| todo[:completed] }

    "<p>#{total_complete} / #{todos.size}</p>"
  end

  def sort_items(items)
    if items == :lists
      @lists.sort_by { |list| list_complete?(list) ? 1 : 0 }
    else
      @todos.sort_by { |todo| todo[:completed] ? 1 : 0 }
    end
  end

  def store_indicies(items)
    if items == :lists
      @lists.map.with_index { |list, idx| [idx, list] }
    else
      @todos.map.with_index { |todo, idx| [idx, todo] }
    end
  end

  def get_original_indicies(items)
    indicies = []
    sort_items(items).each do |sorted_item|
      sel = store_indicies(items).select { |subarray| subarray[1] == sorted_item }
      indicies << sel[0][0]
    end
    indicies
  end
end

before do
  session[:lists] ||= []
end

not_found do
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list
end

def invalid_size?(input)
  !(1..100).cover? input.size
end

def existing_name?(input)
  session[:lists].any? { |list| list[:name] == input }
end

def determine_error(input)
  return if @name == input

  if invalid_size?(input)
    session[:error] = 'The list name must be between 1 and 100 characters.'

  elsif existing_name?(input)
    session[:error] = 'The list name must be unique.'
  end
end

post '/lists' do
  list_name = params[:list_name].strip
  determine_error(list_name)

  if session[:error]
    erb :new_list, layout: :layout

  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

def set_up_list
  @id = params['id'].to_i
  @list = session[:lists][@id]

  if @id >= session[:lists].size
    session[:error] = 'The specified list was not found.'
    redirect '/lists'
  end

  @name = @list[:name]
  @todos = @list[:todos]
end

get '/lists/:id' do
  set_up_list

  erb :todos, layout: :layout
end

get '/lists/:id/edit' do
  set_up_list
  @stored_name = session[:lists][params['id'].to_i][:name]

  erb :edit_list
end

post '/lists/:id' do
  set_up_list

  list_name = params[:list_name].strip
  determine_error(list_name)

  if session[:error]
    erb :edit_list, layout: :layout

  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@id}"

    erb :todos, layout: :layout
  end
end

post '/lists/:id/delete' do
  set_up_list
  session[:lists].delete_at(@id)

  if env["X_REQUESTED_WITH_HTTP"] == 'XMLHttpRequest'
    '/lists'
  
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

post '/lists/:id/todos' do
  set_up_list
  @todo = params['todo'].strip

  error = 'Todo must be between 1 and 100 characters'
  session[:error] = error if invalid_size?(@todo)

  if session[:error]
    erb :todos

  else
    session[:success] = 'The todo was added.'
    @list[:todos] << { name: @todo, completed: false }
    redirect "lists/#{params[:id]}"
  end
end

post '/lists/:id/todos/:index/delete' do
  set_up_list
  todo_index = params[:index].to_i

  @todos.delete_at(todo_index)

  if env["HTTP_X_REQUESTED_WITH"] == 'XMLHttpRequest'
    status 204
  
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@id}"
  end
end

post '/lists/:id/todos/:index' do
  set_up_list
  todo_index = params[:index].to_i
  todo = @todos[todo_index]

  is_completed = params[:completed] == 'true'
  todo[:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@id}"
end

post '/lists/:id/complete_all' do
  set_up_list

  @todos.each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@id}"
end
