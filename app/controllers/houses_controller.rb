class HousesController < ApplicationController
  before_filter :prepare_house
  
  def index
    @houses = House.find :all, :order => "created_at DESC"
  end

  def check
    @title = 'Проверка дома'

    coords = nil
    error  = nil
    house  = nil
    if params[:house] && params[:house][:street] && params[:house][:number]
      begin
        street = params[:house][:street]
        number = params[:house][:number]
        house  = House.find_or_initialize_by_street_and_number(street, number)
        coords = house.coords || begin
          @@dgis ||= DoubleGis.new
          @@dgis.house_coords(street, number)
        end
        error = "Невозможно определить координаты дома" unless coords
      rescue Exception => ex
        logger.error "#{ex.inspect} while ran DoubleGis#house_coords(#{street.inspect}, #{number.inspect})"
        logger.error ex.backtrace.join("\n")
        error = ex.to_s
      end
    end

    respond_to do |format|
      format.html
      format.js {
        render :update do |page|
          page.replace_html('result', :partial => 'house_status', 
            :locals => {:error => error, :house => house}
          )
          page.visual_effect :highlight, 'result'
          if coords
            page << "marker.lonlat.lon = #{coords[0]};"
            page << "marker.lonlat.lat = #{-coords[1]};"
            page << "markers.drawMarker(marker);"
            page << "map.setCenter( new OpenLayers.LonLat( #{coords[0]}, #{-coords[1]} ), 5 );"
            #page << "map.panTo( new OpenLayers.LonLat( #{coords[0]}, #{-coords[1]} ));"
          end
        end
      }
    end
  end

  def new
    @house = House.new
  end

  def create
    @house = House.create params[:house]
    if @house.valid?
      redirect_to houses_path
    else
      render :action => 'new'
    end
  end

  def update
    if params[:house][:street]
      params[:house][:street] = Street.find_or_initialize_by_name params[:house][:street]
    end
    if @house.update_attributes(params[:house])
      flash[:notice] = "Данные дома обновлены"
      redirect_to houses_path
    else
      render :action => 'edit'
    end
  end

  private

  def prepare_house
    if params[:id]
      @house = House.find params[:id].to_i
    end
    true
  end

end
