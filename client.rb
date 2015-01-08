require 'sqlite3'
require 'mail'

module RubyMail
  class Client
    attr_reader :user

    def initialize(username = nil)
      if(username.end_with? "@gmail.com") then username.insert(0, "recent:") end
      database = SQLite3::Database.new("data.db")
      database.execute "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT)"
      database.execute "CREATE TABLE IF NOT EXISTS emails(id INTEGER PRIMARY KEY AUTOINCREMENT, message_id TEXT, text TEXT, html TEXT, from TEXT, to TEXT, subject TEXT, received TEXT, attachment)"
      database.execute("SELECT COUNT(1) FROM users WHERE email = @username", username) do |count|
        if count == [0] then database.execute("INSERT INTO users VALUES(NULL, @username)", username) end
      end
      @user = username
    end
  end
end

Mail.defaults do
  retriever_method :pop3, :address    => "pop.gmail.com",
                          :port       => 995,
                          :user_name  => 'recent:',
                          :password   => '',
                          :enable_ssl => true
end

# Mail.all.each do |email|
#   email.parts.select { |part| part.content_type.include? "text/plain" }.each do |part|
#     puts part.body.decoded
#     puts "--------------"
#   end
# end
# Mail.last.attachments.each do |attachment|
#   if(File.file? "attachments/#{attachment.filename}")
#     puts "There is already a file called #{attachment.filename} in the attachments folder."
#   else
#     File.write("attachments/#{attachment.filename}", attachment.body.decoded)
#     puts "Saved #{attachment.filename}"
#   end
# end