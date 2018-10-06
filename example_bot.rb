require 'cinch'
require_relative 'plugins/lastfm'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.server.net"
    c.channels = ["#channel_name"]
    c.nick = "bot_nick"
    
     c.plugins.plugins = [Cinch::Lastfm]

    c.plugins.options[Cinch::Lastfm] = {
        :api_key => "",
        :shared_secret => "",
      }

  end

end

bot.start
