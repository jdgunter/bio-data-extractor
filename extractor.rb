#!usr/bin/env ruby

require "time"
require "tk"
require "tkextlib/tile"

def db2pa(x)
  10.0**(x/10.0)
end

def pa2db(x)
  10.0*Math.log10(x)
end

$conversion_table = Array.new(200) { |i| db2pa(i) }
$start_date = Date.new(2014, 12, 31)

class LineData

  attr_accessor :values
  attr_accessor :time

  def initialize(string, date)
    words = string.split(" ")
    time_str = words[0].split(":")
    @values = words.drop(words.length - 410)
    @values.each_with_index { |x,i| values[i] = $conversion_table[x.to_i]  }
    hr = time_str[0].to_i
    min = time_str[1].to_i
    sec = time_str[2].to_i
    @time = DateTime.new(date.year, date.month, date.day, hr, min, sec)
  end

end

def extract_data(dirname, filename, t_unit)

  if dirname == nil || filename == nil || t_unit == 0
    return
  end
    
  sum = Array.new(410, 0)
  
  output_file = File.new(filename, "w+")
  input_files = Dir.glob("#{dirname}/*.txt")
  last_file = (input_files.length - 1)

  current_time = nil; last_time = nil; last_data_time = nil
  id = 0; add = 0; bin_size = 0.0; data_counter = 0; day = 0

  current_data = nil;
  
  input_files.sort.each_with_index do |fname, i|

    lines = File.open(fname, "r").readlines
    lines.each_with_index do |line, j|

      line = line.scrub(" ")
      if /Start Date/.match(line[0,10])
        date_string = line.delete("^0-9\-")
        last_time = current_time
        current_time = DateTime.strptime(date_string, "%Y-%m-%d")
      elsif /Author/.match(line[0,6])
        id = line.delete("^0-9").to_i
      elsif /db Ref re 1uPa/.match(line[0,14])
        add = line.delete("^0-9").to_i
      elsif /Bin Width/.match(line[0,9])
        bin_size = line.delete("^0-9.").to_f
      elsif %r{\d\d:\d\d:\d\d}.match(line[0,8])
        current_data = LineData.new(line, current_time)
      end

      # file & line number check
      # if first file && first line of data extracted
      if i == 0 && j == 29
        output_file.write("ID,Date,Day,Time,")
        (0..409).each { |i| output_file.write("#{bin_size*i},") }
        output_file.puts
        last_data_time = current_data.time
        day = (last_data_time.to_date - $start_date).to_i
      end
      
      if j >= 29
        if (current_data.time - last_data_time) >= t_unit || i == last_file && line == lines.last 
          output_file.write("#{id},")
          output_file.write(last_data_time.strftime("%Y/%m/%d,"))
          output_file.write("#{day},")
          output_file.write(last_data_time.strftime("%H:%M:%S,"))
          sum.each { |x| output_file.write("#{pa2db(x/data_counter)},") }
          output_file.puts
          
          sum = Array.new(410,0)
          data_counter = 0
          last_data_time = current_data.time
          day = (last_data_time.to_date - $start_date).to_i
        end
        
        sum.each_index { |i| sum[i] += current_data.values[i] }
        data_counter += 1
      end
      
    end
    
  end
  
end

root = TkRoot.new { title "Extraction Options" }
content = Tk::Tile::Frame.new(root) { padding "3 3 12 12"; width 750; height 500; }.grid(:sticky => 'nsew')
TkGrid.columnconfigure root, 0, :weight => 1; TkGrid.rowconfigure root, 0, :weight => 1

ftypes = [
  ["CSV files", '*csv'],
  ["All files", '*']
]

$dirname = TkVariable.new
$filename = TkVariable.new

$time = TkVariable.new
$hours = TkVariable.new
$minutes = TkVariable.new
$seconds = TkVariable.new

def calculate_time(hr, min, sec)
  hr.to_r/24 + min.to_r/1440 + sec.to_r/86400
end
  
f = Tk::Tile::Button.new(content) {
  text 'Choose Directory'
  command Proc.new { $dirname.value = Tk.chooseDirectory }
}.grid( :column => 1, :row => 1, :sticky => 'e' )

Tk::Tile::Label.new(content) {
  textvariable $dirname
  relief "sunken"  
}.grid( :column => 2, :row => 1, :sticky => 'w' )

Tk::Tile::Button.new(content) {
  text 'Save As...'
  command Proc.new { $filename.value = Tk.getSaveFile(
    "filetypes" => ftypes,
    "defaultextension" => ".csv")
  }
}.grid( :column => 1, :row => 2, :sticky => 'e' )

Tk::Tile::Label.new(content) {
  textvariable $filename
  relief "sunken"  
}.grid( :column => 2, :row => 2, :sticky => 'w' )

Tk::Tile::Label.new(content) {
  text "Hours:"
}.grid( :column => 1, :row => 3, :sticky => 'e' )

Tk::Tile::Entry.new(content) {
  width 7
  textvariable $hours
}.grid( :column => 2, :row => 3, :sticky => 'w' )

Tk::Tile::Label.new(content) {
  text "Minutes:"
}.grid( :column => 1, :row => 4, :sticky => 'e' )

Tk::Tile::Entry.new(content) {
  width 7
  textvariable $minutes
}.grid( :column => 2, :row => 4, :sticky => 'w' )

Tk::Tile::Label.new(content) {
  text "Seconds:"
}.grid( :column => 1, :row => 5, :sticky => 'e' )

Tk::Tile::Entry.new(content) {
  width 7
  textvariable $seconds
}.grid( :column => 2, :row => 5, :sticky => 'w' )

Tk::Tile::Button.new(content) {
  text 'Begin Extraction'
  command {
    extract_data($dirname.value, $filename.value, calculate_time($hours.value, $minutes.value, $seconds.value))
    root.destroy
  }
}.grid( :column => 2, :row => 6 )

TkWinfo.children(content).each { |w| TkGrid.configure w, :padx => 10, :pady => 10 }
f.focus

Tk.mainloop
