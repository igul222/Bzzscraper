%w{cgi open-uri nokogiri mechanize deathbycaptcha}.each {|r| require r }

class DBCCaptchaSolver
  DBC_USERNAME = 'USERNAME HERE'
  DBC_PASSWORD = 'PASSWORD HERE'
  def solve(url)
    begin
      dbc_client = DeathByCaptcha.http_client(DBC_USERNAME, DBC_PASSWORD)
      return dbc_client.decode(url)['text']
    rescue
      return "xyz"
    end
  end
end

class HumanCaptchaSolver
  def solve(url)
    puts "enter solution for CAPTCHA: #{url}"
    return gets.strip
  end
end


class BeeMP3
  DBC_USERNAME = 'USERNAME HERE'
  DBC_PASSWORD = 'PASSWORD HERE'
  BASE_URL = "http://beemp3.com/"
  
  def initialize(query)
    @query = query
  end
  
  def perform_search
    doc = Nokogiri::HTML(open(BASE_URL+"index.php?q=#{CGI.escape @query}&st=all"))
    song_blocks = doc.css('.ieminwidth .ienoscroll .iecontent .fullwidth_search .leftmain .content .left .block')
    results = song_blocks.map {|b| Result.new(b) }
  
    lengths = results.inject(Hash.new(0)) {|hash, result| hash[result.length] += 1; hash}
    lengths = lengths.to_a.sort_by {|length_frequency_pair| -length_frequency_pair[1] }
    ideal_length = lengths[0][0]
    
    return results.sort_by {|r| Math.hypot(r.length - ideal_length,0) }
  end
  
  class Result
    CAPTCHA_SOLVER = DBCCaptchaSolver
    
    attr_accessor :page_url, :length
    
    def initialize(song_block)
      block_text = song_block.to_s
      
      url_string = block_text[/href="[^>]*"/]
      self.page_url = BeeMP3::BASE_URL + url_string[6..(url_string.length-2)]
      
      length_string = block_text.match(/Duration:\s+<span>([0-9:]+)<\/span>/)[1]
      lengths = length_string.split(':').map {|l| l.to_i }
      self.length = lengths[2]+(lengths[1]*60)+(lengths[0]*360)
    end
    
    def mp3_url
      @mp3_url ||= get_mp3_url
    end
    
    def get_mp3_url
      result_url = nil; attempts = 0
      while result_url == nil && attempts < 5
        attempts += 1
        
        print "Attempting to get MP3 URL: retrieving/uploading CAPTCHA..."
        
        agent = Mechanize.new
        page = agent.get(self.page_url)
      
        captcha_url = BeeMP3::BASE_URL + page.images.reject {|i| !i.src || !i.src.include?("code.php") }[0].src
        captcha_rand_element = rand(9999999).to_s
        agent.get(captcha_url).save_as('/Users/ishaan/Dropbox/Public/captcha'+captcha_rand_element)

        loop do
          print "."
          error = false
          begin
            open("http://dl.getdropbox.com/u/413086/captcha#{captcha_rand_element}")
          rescue OpenURI::HTTPError
            error = true if $!.message.include?("404")
          end
          (error ? sleep(2) : break)
        end
        puts ""
        
        print "Processing CAPTCHA..."
        captcha_text = CAPTCHA_SOLVER.new.solve("http://dl.getdropbox.com/u/413086/captcha#{captcha_rand_element}")
        puts "captcha text: #{captcha_text}"
        song_id = self.page_url.match(/file=([0-9]+)/)[1]
      
        result = agent.get("http://beemp3.com/chk_cd.php?id=#{song_id}&code=#{captcha_text}").body
        result_url = result[/http.*/]
        
        puts "Failed: #{result}" if result_url==nil
      end
      puts "Succeeded!"
      result_url
    end
    
  end
  
end

queries = "Young Jeezy - Soul Survivor
Drake - Over
Akon - I'm So Paid
Kevin Rudolf - I Made It
Superchic(K) - Stand In The Rain
Scooter - Where The Beats...
Enrique Iglesias - Tonight (I'm Lovin' You)
PPK - Resurrection (Robots Outro)
Scooter - How Much Is The Fish?".split("\n")

for query in queries
  puts "Scraping BeeMP3 for '#{query}'..."
  bee = BeeMP3.new(query)
  results = bee.perform_search
  puts results.map {|r| r.mp3_url}
end
