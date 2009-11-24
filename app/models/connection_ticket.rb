class ConnectionTicket < Ticket
  before_create :set_dept
  serialize :custom_info

  validates_format_of :vlan, :with => /^\d*$/
  validates_format_of :ip,   :with => /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/, :allow_blank => true

  def title
    "Подключение"
  end

  def set_dept
    self.dept = Dept[:prorabs]
  end

  def update_router_status!
    if vlan.blank?
      self.router_status = "VLAN не назначен"
    elsif ip.blank?
      self.router_status = "IP не назначен"
    else
      status = Router.ip_info ip
      self.router_status =
        if !status.is_a?(Hash)
          status.inspect
        elsif status['error']
          status['error']
        elsif status['interface']
          if self.vlan.to_s == status['interface'].to_s.sub('vlan','')
            'OK'
          else
            status['interface'].to_s
          end
        else
          status.inspect
        end
    end
    if self.router_status != 'OK' && self.created_at_router
      self.router_status = "#{self.router_status}\n(already created)"
    end
    self.save!
  end

  def update_billing_status! ip_info = nil
    if vlan.blank?
      self.billing_status = "VLAN не назначен"
    elsif ip.blank?
      self.billing_status = "IP не назначен"
    else
      status = ip_info || Krus.ip_info(ip)
      Rails.logger.info "KRUS.ip_info: #{status.inspect}"
      self.billing_status =
        if !status.is_a?(Hash)
          status.inspect
        elsif status[:error].to_s.strip == "User not found"
          'OK'
        elsif status[:name]
          if status[:user_id] && status[:user_id].to_i == customer.external_id
            if status[:tarif_id] && status[:tarif_id] == self.tarif_ext_id
              status[:status].try(:[],ip).try(:[],:name) || '??'
            else
              "неверный тариф:\n#{status[:tarif]}"
            end
          else
            "адрес занят:\n#{status[:name]}"
          end
        else
          status.inspect
        end
    end

    if self.billing_status != 'OK' && self.created_at_billing
      self.billing_status = "#{self.billing_status}\n(already created)"
    end
    self.save!
  end

  def can_create_at_router?
    !self.vlan.blank? && !self.ip.blank? && 
      self.router_status.to_s.strip == 'ip not found' && 
      !self.created_at_router
  end

  def can_create_at_billing?
    !self.vlan.blank? && !self.ip.blank? && self.billing_status == 'OK'
  end

  # создать абонента на роутере
  def create_at_router!
    r = Router.create_user! vlan, ip, customer.name_with_address
    Rails.logger.info "Router response: #{r.inspect}"
    self.router_status = r
    if r['OK']
      self.created_at_router = true
    end
    self.save!
  end

  %w'vlan ip tariff_name router_status billing_status created_at_router created_at_billing tarif_ext_id'.each do |m|
    class_eval %Q<
      def #{m}
        custom_info.try(:[], :#{m})
      end
      def #{m}= value
        self.custom_info ||= {}
        self.custom_info[:#{m}] = value
      end
    >
  end

  private

  def after_find
    self.custom_info ||= {}
  end
  alias_method :after_initialize, :after_find
end
