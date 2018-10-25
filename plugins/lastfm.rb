require 'json'
require 'net/http'
require 'date'

class Cinch::Lastfm
  include Cinch::Plugin
 
  listen_to :connect, :method => :setup

  match /last (.+)/, method: :get_last_track
  match /last_info (.+)/, method: :get_user_info

  def setup(*)
    @lastfm_api_key = config[:api_key]
    @lastfm_secret = config[:shared_secret]
  end

  def call_lastfm_api(**args)
    url = "http://ws.audioscrobbler.com/2.0/?&format=json&api_key=#{@lastfm_api_key}"
    args.each do |key, value|
      url << "&#{key}=#{value}"
    end
    uri = URI(URI.escape(url))
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  def get_last_track(m, username)
    last_track = call_lastfm_api(method: "user.getrecenttracks", user: username, limit: "1")
    if last_track.has_key?("error")
      m.reply handle_error(last_track)
    else
      track_name = last_track["recenttracks"]["track"][0]["name"]
      track_mbid = last_track["recenttracks"]["track"][0]["mbid"]
      artist_name = last_track["recenttracks"]["track"][0]["artist"]["#text"]
      album_name = last_track["recenttracks"]["track"][0]["album"]["#text"]
      user_playcount = get_track_playcount(username, artist_name, track_name, track_mbid)
      track = {
        name: track_name,
        mbid: track_mbid,
        artist: artist_name,
        album: album_name,
        playcount: user_playcount
      }
      m.reply "♫ #{Format(:bold, track[:name])} by #{Format(:bold, track[:artist])} on #{Format(:bold, track[:album])} #{track[:playcount]}"
    end
  end

  def get_track_playcount(username, artist, track, *mbid)
    track_info = call_lastfm_api(method: "track.getInfo", user: username, artist: artist, track: track)
    if track_info.has_key?("error")
      handle_error(track_info)
      playcount = ""
    else
      playcount = track_info["track"]["userplaycount"]
      if playcount == "1"
        playcount = "(#{playcount} play)"
      elsif playcount > "1"
        playcount = "(#{playcount} plays)"
      else
        playcount = ""
      end
    end
  end

  def get_user_info(m, username)
    user_info = call_lastfm_api(method: "user.getinfo", user: username)
    if user_info.has_key?("error")
      m.reply handle_error(user_info)
    else
      total_playcount = user_info["user"]["playcount"]
      profile_url = user_info["user"]["url"]
      # Last.fm API returns registration date in UNIX time, requiring conversion and string formatting.
      registration_date = Time.at(user_info["user"]["registered"]["unixtime"]).strftime("%b %d %Y")
      user = {
        playcount: total_playcount.to_s,
        profile: profile_url,
        reg_date: registration_date
      }
      m.reply "👤 #{Format(:bold, username)} · #{Format(:bold, user[:playcount])} plays since #{Format(:bold, user[:reg_date])} · #{user[:profile]}"
    end
  end

  def handle_error(error_hash)
    warn "ERROR ENCOUNTERED:"
    warn "last.fm API returned \"#{error_hash["message"]}\" (error code #{error_hash["error"]})"
    "error: #{error_hash["message"]}"
  end

end