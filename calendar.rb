require 'rubygems'
require 'RMagick'
require 'prawn'
require 'prawn/measurement_extensions'
require 'yaml'

class Calendar
 attr_accessor :days, :tasks_counter, :width, :height, :dimensions, :special_events 
 attr_accessor :daily_tasks, :color_schemes, :weekly_tasks, :monthly_tasks
 
 
 def initialize(start_date = Date.today, end_date = Date.today + 1)
  @settings = YAML::load( File.open( 'settings.yaml' ) )
  @color_schemes = @settings["colors"]
  @daily_tasks =  @settings["daily tasks"]
  @weekly_tasks =  @settings["weekly tasks"]
  @weekly_todo = @settings["weekly todo"]
  @monthly_tasks = @settings["monthly tasks"]
  @special_events = @settings["special events"]
  @dimensions = @settings["dimensions"]
  @width = @dimensions["width"]
  @height = @dimensions["height"]
  
  @tasks_counter = 1
  @days = []
  dates = (start_date..end_date).to_a
  tasks = week_o_tasks
  dates.each do |date|
    if tasks.length == 0
     tasks = week_o_tasks 
    end
    
    page = Page.new(date, self)
    page.event = self.special_events[date.strftime('%-m-%-e')]
    page.task = tasks.pop
    @days << page
  end
 end
  
 #randomly assigns weekly and monthly tasks, should be changed so monthly tasks are evenly distributed
 def week_o_tasks
   monthly_task = @monthly_tasks[@tasks_counter % @monthly_tasks.length]
   @tasks_counter = @tasks_counter + 1
   all_tasks = @weekly_tasks << monthly_task
   all_tasks.shuffle
 end
   
 def make_printable
    Dir.chdir "days"
    raster_days = Dir.glob("*.png")
    puts "globbed OK"
    pdf = Prawn::Document.new
  
    raster_days.each do |path|
      puts path
      pdf.image path, :width => dimensions['page width'].in
    end
    pdf.render_file "./calendar.pdf"
 end
 
end

class Page
  include Magick
  
  attr_accessor :date, :color_scheme, :calendar, :task, :event
  
  
  def initialize(date, calendar)
    @date = date
    @calendar = calendar
    
    #set the page's color scheme 
    available_schemes = @calendar.color_schemes
    @color_scheme = available_schemes[rand(available_schemes.length)]
    
  end
  
  #draws the graphic for the page
  def prepare
    puts "Preparing #{@date.to_s}"
    @graphic = ImageList.new
    
    #set background color
    bg_color = @color_scheme['main']
    @graphic.new_image(@calendar.width, @calendar.height) { self.background_color = bg_color }
    
    #add cloud background
    cloud = @graphic.read('cloud.png')
    
    #add daily tasks
    everyday_tasks
    dot
    weekly_task
    dot
    todos
    dot
    
    #add the date at the top
    date_header
    dot
    
    #add the special event
    special_event
    dot
  end
  
  def date_header
    
    ldate = @graphic.new_image(@calendar.width, @calendar.height) { self.background_color = '#FF00FF00' }
    
    #first we place the day number    
    gc = Magick::Draw.new
    gc.fill(@color_scheme['text'])
    gc.font('Walkway/Walkway_Black.ttf')
    gc.pointsize = 84
    gc.align = RightAlign
    ga = gc.dup
    monthdate = @date.strftime('%e').to_i.ordinal
    gc.text(1480,160, monthdate)
    
    #calculate the width of the ordinalized date
    metrics = gc.get_type_metrics(ldate, monthdate)
    
    #change the font and place the month name to the left of the date
    monthright = 1480 - (metrics.width + 20)
    gc.font('Walkway/Walkway_SemiBold.ttf')
    gc.text(monthright,160, @date.strftime('%B'))
    #get the width of the month name
    mmetrics = gc.get_type_metrics(ldate, @date.strftime('%B'))
    
    line = Draw.new
    line.stroke = @color_scheme['primary']
    line.line(1480 - (metrics.width + mmetrics.width),180,1480,180)
    line.draw(ldate)
    
    #add the day of the week below
    ga.font('Walkway/Walkway_SemiBold.ttf')
    ga.pointsize = 63
    ga.text(1480,240, @date.strftime('%A'))
    
    
    gc.draw(ldate)
    ga.draw(ldate)
  end
  
  def everyday_tasks
    gc = Magick::Draw.new
    gc.fill(@color_scheme['text'])
    gc.font('Walkway/Walkway_SemiBold.ttf')
    
    circle = Magick::Draw.new
    circle.stroke(@color_scheme['main'])
    circle.fill_opacity(0)
    circle.stroke_opacity(1)
    circle.stroke_width(2)
    circle.stroke_linecap('round')
    circle.stroke_linejoin('round')
    
    #new layer for the daily tasks
    ltasks = @graphic.new_image(@calendar.width, @calendar.height) { self.background_color = '#FF00FF00' }
    
    #hard coded positions of the checkcircles
    coords = [[113,950],[800,950],[113,1050],[563,1050],[1087,1050],[113,1150],[975,1150]]
    
    i = 0
    coords.each do |x,y|
      circle.ellipse(x,y, 25, 25, 0, 360)
      gc.text(x+45, y+23, self.calendar.daily_tasks[i])
      i = i+1
    end
    circle.draw(ltasks)

    
    gc.pointsize = 63
    gc.draw(ltasks)
    
  end
  
  def special_event
    #get today's event from the calendar
    event = @event
    if event.nil?
       return false
    end
    @graphic.new_image(@calendar.width, @calendar.height) { self.background_color = '#FF00FF00' }
    levent = @graphic.cur_image
    scene = @graphic.scene
    
    capsule = Draw.new
    capsule.fill = @color_scheme['secondary']
    gc = Draw.new
    gc.font('Walkway/Walkway_Bold.ttf')
    gc.fill('#ffffff')
    gc.pointsize = 58
    metrics = gc.get_type_metrics(levent, event) 
    #pixel positions
    radius = 50
    lside = @calendar.width/2 - metrics.width/2
    top = 785
    rside = @calendar.width/2 + metrics.width/2 + radius
    bottom = top + 2 * radius
    
    capsule.roundrectangle(lside, top, rside, bottom, radius, radius)
    gc.text(lside + radius, top + radius + 20, event)
    
    capsule.draw(levent)
    gc.draw(levent)
    
    #create a drop shadow
    shadow = Image.read('shadow.png')
    #composite the drop shadow with the drawn shapes and replace the original shapes with the composite
    @graphic[scene] = shadow[0].composite(levent, Magick::NorthWestGravity, Magick::OverCompositeOp)
  end
  
  def todos
    #heading
    ltodo = @graphic.new_image(@calendar.width, @calendar.height) { self.background_color = '#FF00FF00' }
    heading = Draw.new
    heading.font('Walkway/Walkway_SemiBold.ttf')
    heading.pointsize = 63
    heading.fill(@color_scheme['text'])
    heading.kerning(3)
    heading.text(115,405, "Today's Goals")
    taskborder = Draw.new
    taskborder.fill('#ffffff')
    taskborder.stroke(@color_scheme['text'])
    taskborder.rectangle(80,320,575,450)
    taskborder.stroke_antialias(false)
    
    4.times do |i|
      taskborder.line(210,519 + i*75, 1460,519 + i*75)
    end

    taskborder.draw(ltodo)
    heading.draw(ltodo)

    
    #add checkboxes
    4.times do |i|
      checkbox = @graphic.read('checkbox.png')
      checkbox.page = Rectangle.new(46,46,112,480 + i*75)
      end


  end
  
  def weekly_task
    task = @task
    
    lweekly = @graphic.new_image(@calendar.width, @calendar.height) { self.background_color = '#FF00FF00' }
    capsule = Draw.new
    capsule.fill = @color_scheme['primary']
    tasktext = Draw.new
    tasktext.font('Walkway/Walkway_Black.ttf')
    tasktext.pointsize = 63
    tasktext.fill('#ffffff')
    tasktext.kerning(3)
    #pixel positions
    metrics = tasktext.get_type_metrics(lweekly,task)
    radius = 60
    top = 92
    lside = 94
    bottom = top + 2 * radius
    #right is left, plus 2 radii for either end, plus half width of checkmark, plus text
    rside = lside + 2 * radius + 50 + metrics.width
    
    #draw the shape
    capsule.roundrectangle(lside, top, rside, bottom, radius, radius)
    tasktext.text(lside + 101 + 40, top + radius + 21, task)

    capsule.draw(lweekly)  
    tasktext.draw(lweekly)

    lweekly_check = @graphic.read('weekcheck.png')
    lweekly.page = Rectangle.new(100,101,lside + 20, top + 10)
  end
  
  def draw
    t = @graphic.flatten_images
    t.write('./days/' + date.to_s + '.png')
  end
  
  #output for debugging / progress
  def dot
    print "."
    $stdout.flush
  end

end

class Numeric
  def ordinal
    cardinal = self.to_i.abs
    if (10...20).include?(cardinal) then
      cardinal.to_s << 'th'
    else
      cardinal.to_s << %w{th st nd rd th th th th th th}[cardinal % 10]
    end
  end
end
