require './client.rb'
require './utils.rb'
require 'io/console'

module RubyMail
  class ConsoleInterface
    def initialize
      login
      start_sync
    end

    def login
      print "Username: "
      user_name = gets.chomp
      if(Utilities.user_exists? user_name)
        @client = Client.new(user_name)
      else
        print "Password: "
        password = STDIN.noecho(&:gets).chomp
        print "\nPOP3 Server: "
        pop3 = gets.chomp
        print "POP3 Server Port: "
        pop3_port = gets.chomp.to_i
        print "Enable SSL? (0 or 1): "
        ssl = gets.chomp.to_i
        print "SMTP Server: "
        smtp = gets.chomp
        print "SMTP Server Port: "
        smtp_port = gets.chomp.to_i
        @client = Client.new(user_name, password, pop3, pop3_port, ssl, smtp, smtp_port)
      end
    end

    def start_sync
      @syncer = Thread.new do
        while true do
          @client.sync_mail
          sleep(60)
        end
      end
    end
  end
end

RubyMail::ConsoleInterface.new
gets