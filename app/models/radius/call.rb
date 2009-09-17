class Radius::Call < ActiveRecord::Base
  establish_connection "radius_#{RAILS_ENV}" if configurations["radius_#{RAILS_ENV}"]

  set_table_name 'radacct'
  set_primary_key 'radacctid'
  default_scope :order => "acctstarttime, acctstoptime"

  def caller
    callingstationid ? callingstationid.to_i : nil
  end

  def start_time
    self.acctstarttime
  end

  def end_time
    self.acctstoptime
  end

  def ended?
    self.acctstoptime != nil
  end

  def answered?
    self.ended? && self.acctsessiontime.to_i > 0
  end

  def duration
    if self.ended? || self.acctsessiontime.to_i > 0
      self.acctsessiontime
    else
      [0, Time.now - self.acctstarttime].max
    end
  end

  def night?
    t = self.acctstarttime
    ([0,6].include?(t.wday)) ? (t.hour>16 || t.hour<10) : (t.hour>18 || t.hour<9)
  end

  # from 'caller' (source number) field now
  # because destination number is always our support phone number
  def customer
    return @customer if defined?(@customer)
    @customer = (caller ? Customer.find_by_phone(caller) : nil)
  end

  attr_writer :customer

  # creates ::Call records
  def self.export_to_call_archive
    last_time = Settings['radius.call.last_export'] || Time.now - 1.year
    new_radius_calls = all(
      :conditions => [
        "acctstoptime IS NOT NULL AND (acctstoptime > ? OR acctstarttime > ?)",
        last_time,
        last_time
      ],
      :order      => "acctstarttime"
    )
    return if new_radius_calls.blank?

    new_calls = []
    new_radius_calls.each do |radius_call|
      call = ::Call.new(
        :start_time   => radius_call.start_time,
        :duration     => radius_call.duration,
        :phone_number => Phone.canonicalize(radius_call.caller),
        :customer     => Customer.find_by_phone(radius_call.caller)
      )
      if call.valid?
        call.save!
        new_calls << call
      end
    end

    Settings['radius.call.last_export'] = new_radius_calls.map(&:end_time).max
    new_calls
  end

  cattr_reader :error_description

  def self.configured?
    return true if self.table_exists?
    @@error_description = "Таблица \"#{table_name}\" не существует"
    false
  rescue
    @@error_description = $!.to_s
    false
  end
end
