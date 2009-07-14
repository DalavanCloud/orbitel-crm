class Customer < ActiveRecord::Base
  before_save :cleanup_name

  has_many :phones, :dependent => :delete_all do
    def add phone
      phones = Phone.from_string_or_array(phone)
      phones.each do |ph|
        next unless ph.valid?
        next if proxy_owner.phones.map(&:number).include?(ph.number)
        proxy_owner.phones << ph
      end
    end
  end

  def initialize *args
    if args.first.is_a?(Hash)
      phones   = args.first.delete(:phones)
      phones ||= args.first.delete(:phone).to_a
      if phones.any?
        args.first[:phones] = Phone.from_string_or_array(phones)
      end
    end
    super
  end

  def self.find_by_phone phone_number
    Phone.find_by_number(Phone.canonicalize(phone_number)).try(:customer)
  end

  private

  def cleanup_name
    self.name.strip!
    self.name.gsub!(/ {2,}/,' ')
    self.name.gsub!(/[иИ]ндивидуальный [Пп]редприниматель/ui,'ИП')
    self.name.gsub!(/[гГ]осударственное [оО](бластное|бразовательное) [уУ]чреждение/ui,'ГОУ')
    self.name.gsub!(/[гГ]осударственное [уУ]чреждение/ui,'ГУ')
    self.name.gsub!(/[сС]реднего [пП]рофессионального [оО]бразования/ui,'СПО')
    self.name.gsub!(/[Зз3]акрытое [аА]кционерное [оО]б[шщ]ество/ui,'ЗАО')
    self.name.gsub!(/[оО]ткрытое [аА]кционерное [оО]б[шщ]ество/ui,'ОАО')
    self.name.gsub!(/[оО]б[шщ]ество [сС] [оО]граниченн?ой [оО]тветственн?остью/ui,'ООО')
    self.name.gsub!(/[Мм]униципальное [дД]ошкольное [оО]бразовательное [уУ]чреждение/ui,'МДОУ')
    self.name.gsub!(/[Мм]униципальное [уУ]чреждение/ui,'МУ')
    self.name.gsub!(/Федеральное [гГ]осударственное [уУ]нитарное [Пп]редприятие/ui,'ФГУП')
    self.name.gsub!(/Федеральное [гГ]осударственное [уУ]чреждение [Зз3]дравоохранения/ui,'ФГУЗ')
    self.name.gsub!(/[гГ]\. [Кк]урган/ui,'г.Курган')
    self.name.gsub!(/[«»]/u,'"')
    self.name.tr!("`'",'""""')
    self.name.sub!(/^"(.+)"$/,'\1')
    self.name.strip!
  end
end
