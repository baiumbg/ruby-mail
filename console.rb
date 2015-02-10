require './client.rb'
require './utils.rb'
require 'io/console'

module RubyMail
  class ConsoleInterface
    def initialize
      login
      start_sync
      start_shell
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
        pop3_ssl = gets.chomp.to_i

        print "SMTP Server: "
        smtp = gets.chomp

        print "SMTP Server Port: "
        smtp_port = gets.chomp.to_i

        print "Enable SSL? (0 or 1): "
        smtp_ssl = gets.chomp.to_i

        @client = Client.new(user_name, password, pop3, pop3_port, pop3_ssl, smtp, smtp_port, smtp_ssl)
      end
    end

    def start_shell
      system "cls" or system "clear"
      cmd = ""
      while(cmd != "quit") do
        print "#{@client.email}$ "
        cmd = gets.chomp
        process_cmd cmd
      end
    end

    def process_cmd(cmd)
      args = cmd.split ' '
      case args[0]
      when "read"
        if(args.length > 2) 
          puts "Too many arguments."
        elsif(args.length < 2)
          puts "Missing arguments."
        else
          read(args[1].to_i)
        end
      else
        puts "Unknown command."
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

test = RubyMail::ConsoleInterface.new