class Ticket < ActiveRecord::Base
  belongs_to :house
  belongs_to :created_by, :class_name => 'User'
  belongs_to :assignee,   :class_name => 'User'

  has_many :ticket_history_entries, :order => 'created_at DESC'
  alias :history :ticket_history_entries

  validates_associated :house

  accepts_nested_attributes_for :house

  default_scope :order => 'created_at'

  after_create :log_new_ticket

  CONTACT_TYPE_UR  = 1
  CONTACT_TYPE_FIZ = 2

  PRIORITY_HIGHEST = 10
  PRIORITY_HIGH    = 5
  PRIORITY_NORMAL  = 0
  PRIORITY_LOW     = -5
  PRIORITY_LOWEST  = -10

  PRIORITIES = [10, 5, 0, -5, -10]

  # statuses
  ST_NEW       = 0
  ST_ACCEPTED  = 5
  ST_CLOSED    = 10
  ST_REOPENED  = 15

  STATUSES = [0, 5, 10, 15]

  # create a house/street if needed, or find an existing by their attributes
  def initialize *args
    if args.first.is_a?(Hash) && (house_attrs=(args.first[:house] || args.first[:house_attributes])).is_a?(Hash)
      street = if house_attrs[:street_id]
        Street.find house_attrs[:street_id]
      elsif house_attrs[:street]
        Street.find_or_initialize_by_name house_attrs[:street]
      else
        Street.new
      end

      house = if street.new_record?
        House.new(
          :number => house_attrs[:number],
          :street => street
        )
      else
        House.find_or_initialize_by_street_id_and_number(
          street.id,
          house_attrs[:number]
        )
      end

      args.first[:house] = house
      args.first.delete :house_attributes
    end
    super *args
  end

  def address
    if house
      "#{house.street.try(:name)} #{house.number}" + (flat.blank? ? '' : "-#{flat}")
    else
      nil
    end
  end

  def change_status! new_status, options = {}
    if options[:user] 
      if options[:assign]
        self.assignee = options[:user]
      end
      self.history << TicketHistoryEntry.new(
        :user => options[:user],
        :old_status => self.status,
        :new_status => new_status
      )
    end
    self.status = new_status
    self.save!
  end

  private

  def log_new_ticket
    self.history.create!(
      :user => self.created_by,
      :old_status => nil,
      :new_status => self.status
    )
  end
end
