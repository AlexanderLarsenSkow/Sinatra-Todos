require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = [
    {name: "Lunch Grociers", todos: [] },
    {name: "Dinner Grociers", todos: []}
  ]

  erb :lists, layout: :layout
end
