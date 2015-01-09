require 'sqlite3'
require 'mail'

module RubyMail
  class Client
    attr_reader :user

    def initialize(username = nil)
      @user = username
      database = SQLite3::Database.new("data.db")
      database.execute "CREATE TABLE IF NOT EXISTS users(`id` INTEGER PRIMARY KEY AUTOINCREMENT, `email` TEXT, `password` TEXT)"
      database.execute "CREATE TABLE IF NOT EXISTS emails(`id` INTEGER PRIMARY KEY AUTOINCREMENT, `message_id` TEXT, `text` TEXT, html TEXT, `from` TEXT, `to` TEXT, `subject` TEXT, `received` TEXT)"
      database.execute "CREATE TABLE IF NOT EXISTS attachments(`id` INTEGER PRIMARY KEY AUTOINCREMENT, `message_id` TEXT, `file_name` TEXT, `attachment` BLOB)"
      result = database.execute("SELECT * FROM `users` WHERE `email` = @username", username)
        #if result.count == 0 then database.execute("INSERT INTO users VALUES(NULL, @username)", username) end
  		Mail.defaults do
  		  if(username.end_with? "@gmail.com") then username.insert(0, "recent:") end
  		  retriever_method :pop3, :address    => "pop.gmail.com",
  		                          :port       => 995,
  		                          :user_name  => username,
  		                          :password   => result[0][2],
  		                          :enable_ssl => true
  		end
      Mail.all.each do |mail|
        database.execute(
          "IF NOT EXISTS (SELECT * FROM emails WHERE `email` = '@username' AND `message_id` = '@id') INSERT INTO emails VALUES(NULL, @id, @text, @html, @from, @to, @subject, @received)",
          @user,
          mail.message_id,
          mail.text_part,
          mail.html_part,
          mail.from,
          mail.to,
          mail.subject,
          mail.date
        )
        mail.attachments.each do |attachment|
          database.execute(
            "IF NOT EXISTS (SELECT * FROM attachments WHERE `message_id` = '@id')
            INSERT INTO attachments VALUES(NULL, @id, @file_name, @attachment",
            mail.message_id,
            attachment.filename,
            attachment.body.decoded
          )
        end
      end
    end
  end
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

test = RubyMail::Client.new("baiumbg@gmail.com")
#p Mail.last.subject