require 'cgi'
require 'yaml'

class Krus
  cattr_accessor :host, :port, :key

  def self.fetch_customers
    fetch_yaml_url "report/users.yaml?no_zombies=1"
  end

  def self.fetch_tariffs
    fetch_yaml_url "tarifs.yaml"
  end

  def self.user_info uid
    fetch_yaml_url "user_info/#{uid.to_i}.yaml"
  end

  def self.user_traf_info uid, args={}
    url = "user_traf_info/#{uid.to_i}.yaml"
    if args.any?
      url += "?" + args.map{ |k,v| "#{k}=#{v}" }.join('&')
    end
    r = fetch_yaml_url url
    #(r.is_a?(Hash) && r.key?(:traf)) ? r[:traf] : r
    r
  end

  # Включить/выключить юзеру доступ в инет
  # возвращает то же, что и в user_info
  def self.user_toggle_inet uid, state
    st = state ? 'on' : 'off'
    fetch_yaml_url "user_info/#{uid.to_i}.yaml?toggle=#{st}&key=#{key}"
  end

  # Коррекция баланса юзера
  # возвращает то же, что и в user_info
  def self.user_correct_balance uid, amount, comment
    fetch_yaml_url(
      "payments/correct_balance/#{uid.to_i}" +
        "?amount=#{CGI.escape(amount)}" + 
        "&comment=#{CGI.escape(comment)}" + 
        "&key=#{key}",
      true
    )
  end

  private

  def self.fetch_yaml_url url, follow_redirect = false
    url = URI.parse "http://#{host}:#{port}/#{url}"
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.read_timeout = 600
      http.get(url.request_uri)
    }

    if RAILS_ENV == 'development'
      Rails.logger.info("KRUS status:   #{res.code} #{res.msg}")
      Rails.logger.info("KRUS redirect: #{res['location']}") unless res['location'].blank?
      Rails.logger.info("KRUS body:     #{res.body}") 
    end

    if follow_redirect && res.is_a?(Net::HTTPRedirection)
      return fetch_yaml_url( 
        res['location'].
        sub("http://#{host}:#{port}/",''). # make location relative (DIRTY!)
        sub("http://#{host}/",'')
      )
    end

    YAML::load( res.body )
  end
end
