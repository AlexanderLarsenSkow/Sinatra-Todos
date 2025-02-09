# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubi'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
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
end

before do
  session[:lists] ||= []
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
  @name = @list[:name]
  @todos = @list[:todos]
end

get '/lists/:id' do
  set_up_list

  erb :todos, layout: :layout
end

get '/lists/:id/edit' do
  @id = params['id']
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
    redirect "/lists/#{@index}"

    erb :todos, layout: :layout
  end
end

post '/lists/:id/delete' do
  set_up_list
  session[:lists].delete_at(@id)
  session[:success] = 'The list has been deleted.'

  redirect '/lists'
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
  session[:success] = 'The todo has been deleted.'

  redirect "/lists/#{@id}"
end
