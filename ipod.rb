require 'rubygems'
require 'gosu'

BACKGROUND = Gosu::Image.new('./ipod/ipod.jpg')
TrackLeftX = 314
TRACKS_PER_PAGE = 12
DEFAULT_MENU_POSITION = [28, 65]
START_END_DEFAULT = [0, 12]
LEFT_ARROW = [123, 825]
RIGHT_ARROW = [366, 825]
UP_ARROW = [247, 700]
DOWN_ARROW = [247, 944]

FONT = {
  :name => './font/Nunito-Bold.ttf'
}

module ZOrder
  BACKGROUND, MENU, UI = *0..2
end

############################################################# MAIN CLASSES #################################################################
class Album
  attr_accessor :name, :tracks, :picture, :artist, :image
  def initialize(name, artist, picture, tracks)
    @name = name
    @artist = artist
    @tracks = tracks
    @picture = picture
    @image = Gosu::Image.new(picture) 
  end
end

class Track
  attr_accessor :name, :location
  def initialize(name, location)
    @name = name
    @location = location
  end
end

class MusicPlayerMain < Gosu::Window
  #################################################################### INITIALIZE #################################################################
  def initialize
    super 591, 1175
    self.caption = "Music Player"
    @music_folder = "./albums"
    initialize_album

    @font = Gosu::Font.new(40, options = FONT)

    @track_index = 0
    @track_start_display = 0
    @track_end_display = 12
    @track_option = 0
    @track_modifying = false
    @track_to_modify = nil
    @meme = Gosu::Image.new('./ipod/meme.png')
    @liked_tracks = []
    
    @current_album = nil
    @selected_album = nil
    @album_index = 0
    @is_playing = false
    @current_playing_track = nil
    @show_playing_track = false

    @menu = Gosu::Image.new('./ipod/menu.jpg')
    @menu_extended = Gosu::Image.new('./ipod/menu_extended.jpg')
    @menu_extended_2 = Gosu::Image.new('./ipod/menu_extended_2.jpg')
    @arrow_up = Gosu::Image.new('./ipod/arrow_up.png')
    @arrow_down = Gosu::Image.new('./ipod/arrow_down.png')
    @arrow_left = Gosu::Image.new('./ipod/arrow_left.png')
    @arrow_right = Gosu::Image.new('./ipod/arrow_right.png')
    @page = Gosu::Image.new('./ipod/page.png')

    @album_directories = Dir[@music_folder + '/*']

    @on_favourites_page = false
    @on_albums_page = false
    @on_songs_page = false
    @on_a_page = false
    @main_menu_option = 0
    @page_navigation = 0
  end

  def initialize_album
    @albums = read_albums(@music_folder)
    @tracks_state = {}
    @all_tracks = {}
    if !@albums.empty?
      for album in @albums
        for track in album.tracks
          @tracks_state[track] = false
          @all_tracks[track] = album.artist
        end
      end
    end
  end

  def read_tracks(album_folder)
    track_files = Dir[album_folder + '/*.{wav,flac,mp3}']
    tracks = track_files.map do |file|
      name = File.basename(file, File.extname(file))
      Track.new(name, file)
    end
    return tracks
  end

  def read_albums(music_folder)
    albums = []
    album_folders = Dir[music_folder + '/*']
    if !album_folders.empty?
      album_folders.each do |album_folder|
        album_image = Dir[album_folder + '/*.{jpg,png,jpeg}'][0]
        album_image ||= './ipod/default_album_cover.jpg'
        album_name = File.basename(album_folder).split(' - ')[1]
        album_artist = File.basename(album_folder).split(' - ')[0]
        tracks = read_tracks(album_folder)
        albums << Album.new(album_name, album_artist, album_image, tracks)
      end
    else
      return []
    end
    return albums
  end

  #################################################################### MAIN LOGIC #################################################################
  ############### TRACK LOGIC #################
  def tracks_navigation(tracks, track_page)
    @current_playlist = tracks
    max_index = [tracks.length, 12].min
    if !@track_modifying
      if max_index == 12
        if arrow_hovered?(*UP_ARROW)
          if @track_index > 0
            @track_index -= 1
          elsif @track_index == 0 && @track_start_display > 0
            @track_start_display -= 1
            @track_end_display -= 1
          end
        elsif arrow_hovered?(*DOWN_ARROW)
          if @track_index < 11
            @track_index += 1
          elsif @track_end_display < tracks.length
            @track_start_display += 1
            @track_end_display += 1
          end
        end
      else
        if arrow_hovered?(*UP_ARROW)
          if @track_index > 0
            @track_index -= 1
          end
        elsif arrow_hovered?(*DOWN_ARROW)
          if @track_index + 1 < max_index
            @track_index += 1
          end
        end
      end

      if choose && @page_navigation == track_page
        @show_playing_track = true
        playTrack(@track_index + @track_start_display, @current_playlist)
      end
    end

    if arrow_hovered?(*RIGHT_ARROW)
      @track_modifying = true
      @track_to_modify = tracks[@track_index + @track_start_display]
    end
  end

  def playTrack(track, tracks)
    @is_playing = true
    @current_playing_track = @current_playlist[track]
    @current_track_index = track
    @song = Gosu::Song.new(@current_playing_track.location)
    @song.play(false)
  end

  def no_liked_tracks?(hash)
    hash.each do |key, value|
      return false if value == true
    end
    true
  end

  def track_options(track)
    if @track_option < 2 && arrow_hovered?(*DOWN_ARROW)
      @track_option += 1
    elsif @track_option > 0 && arrow_hovered?(*UP_ARROW)
      @track_option -= 1
    elsif arrow_hovered?(*LEFT_ARROW)
      @track_modifying = false
      @track_to_modify = nil
    end

    if choose
      case @track_option
      when 0
        @tracks_state[track] = !@tracks_state[track]
      when 1
        @track_modifying = false
        @track_to_modify = nil
        File.delete(track.location)
        @selected_album.tracks.delete(track) if !@selected_album.nil?
      when 2
        @show_playing_track = true
        playTrack(@current_playlist.find_index(track), @current_playlist)
      end
      @track_modifying = false
      @track_to_modify = nil
    end
  end

  ############### ALBUM LOGIC #################
  def album_page_control
    if arrow_hovered?(*RIGHT_ARROW)
      if @album_index < @albums.length - 1
        @album_index += 1
      end
    elsif arrow_hovered?(*LEFT_ARROW)
      if @album_index > 0
        @album_index -= 1
      end
    end

    if choose && @page_navigation == 2
      @selected_album = @albums[@album_index]
    elsif arrow_hovered?(*LEFT_ARROW) && !@track_modifying
      @selected_album = nil
      @page_navigation = 1
    end

    if !@selected_album.nil?
      if !@selected_album.tracks.empty?
        tracks_navigation(@selected_album.tracks, 3)
      end
    else
      @track_start_display, @track_end_display = START_END_DEFAULT
      @track_index = 0
    end
  end

  ############### PAGE RESET #################
  def reset_pages
    @on_a_page = false
    @on_favourites_page = false
    @on_albums_page = false
    @on_songs_page = false
    @track_modifying = false
    @show_playing_track = false
    @page_navigation = 0
  end

  #################################################################### DRAW #################################################################
  def display_tracks(tracks, start_index, end_index)
    ypos = 73
    min = [end_index, tracks.length].min
    if min == end_index
      tracks[start_index...end_index].each do |track|
        @font.draw(track.name, 35, ypos, ZOrder::UI, 0.7, 0.7, Gosu::Color::WHITE)
        ypos += 42.23
      end
    else
      tracks[0...min].each do |track|
        @font.draw(track.name, 35, ypos, ZOrder::UI, 0.7, 0.7, Gosu::Color::WHITE)
        ypos += 42.23
      end
    end
  end

  def draw_track_options(track)
    option = ['Add to favourites', 'Delete track', 'Play']
    if @tracks_state[track] == true
      option[0] = 'Remove from favourites'
    end
    ypos = 72
    option.each do |text|
      @font.draw(text, 35, ypos, ZOrder::UI, 0.7, 0.7, Gosu::Color::WHITE)
      ypos += 42.23
    end
  end

  def draw_wrapped_text(text, x, y, width, font)
    lines = []
    current_line = ""
    text.split.each do |word|
      if font.text_width("#{current_line} #{word}") > width
        lines << current_line
        current_line = word
      else
        current_line += " #{word}"
      end
    end
    lines << current_line unless current_line.empty?
    lines.each_with_index do |line, index|
      font.draw_text(line.strip, x, y + index * font.height - 80, ZOrder::UI, 0.7, 0.7, Gosu::Color::WHITE)
    end
  end

  def draw_playing_track(track)
    draw_page('Playing')
    @meme.draw(100, 230, ZOrder::UI, 0.3, 0.3)
    draw_wrapped_text(track.name, 280, 320, 400, @font)
    @font.draw("By: #{@all_tracks[track]}", 280, 340, ZOrder::UI, 0.7, 0.7, Gosu::Color::WHITE)
  end

  def draw_menu
    menu_list = ['Favourites', 'Albums', 'Songs']
    ypos = 72
    menu_list.each do |text|
      @font.draw(text, 35, ypos, ZOrder::MENU, 0.7, 0.7, Gosu::Color::WHITE)
      ypos += 42.23
    end
  end

  def background
    BACKGROUND.draw(0, 0, ZOrder::BACKGROUND, 1, 1)
    @arrow_up.draw(*UP_ARROW, ZOrder::BACKGROUND, 0.2, 0.2)
    @arrow_down.draw(*DOWN_ARROW, ZOrder::BACKGROUND, 0.2, 0.2)
    @arrow_left.draw(*LEFT_ARROW, ZOrder::BACKGROUND, 0.2, 0.2)
    @arrow_right.draw(*RIGHT_ARROW, ZOrder::BACKGROUND, 0.2, 0.2)
  end

  def draw_page(text)
    @page.draw(28, 27, ZOrder::UI, 1, 1)
    @menu_extended.draw(27, 26, ZOrder::UI, 1, 1)
    @font.draw(text, 34, 31, ZOrder::UI, 0.66, 0.66, Gosu::Color::WHITE)
  end

  def draw_albums_page
    if !@selected_album.nil?
      if !@selected_album.tracks.empty?()
        draw_page(@selected_album.name)
        @menu_extended_2.draw(28, 65 + 42.23 * @track_index, ZOrder::UI, 1.005, 0.93)
        display_tracks(@selected_album.tracks, @track_start_display, @track_end_display)
      end
    else
      draw_page('Albums')
      if !@albums.empty?()
        draw_album(@albums[@album_index])
      else
        @font.draw('See your albums here', 174, 144, ZOrder::UI, 0.8, 0.8, Gosu::Color.argb(0xff_808080))
      end
    end
  end

  def draw_favourites_page
    draw_page('Favourites')
    if no_liked_tracks?(@tracks_state)
      @font.draw('See your favourite tracks here', 126, 144, ZOrder::UI, 0.8, 0.8, Gosu::Color.argb(0xff_808080))
    else
      @menu_extended_2.draw(28, 65 + 42.23 * @track_index, ZOrder::UI, 1.005, 0.93)
      display_tracks(@liked_tracks, @track_start_display, @track_end_display)
    end
  end

  def draw_songs_page
    draw_page('Songs')
    if !@all_tracks.empty?()
      @menu_extended_2.draw(28, 65 + 42.23 * @track_index, ZOrder::UI, 1.005, 0.93)
      display_tracks(@all_tracks.keys, @track_start_display, @track_end_display)
    else
      @font.draw('See your songs here', 180, 144, ZOrder::UI, 0.8, 0.8, Gosu::Color.argb(0xff_808080))
    end
  end

  def draw_album(album)
    album.image.draw(136, 126, ZOrder::UI, 640 * 0.5 / album.image.height, 640 * 0.5 / album.image.height)
    @font.draw(album.name, 140, 444, ZOrder::UI, 0.8, 0.8, Gosu::Color::WHITE)
    @font.draw("By: #{album.artist}", 140, 466, ZOrder::UI, 0.8, 0.8, Gosu::Color::WHITE)
  end

  #################################################################### MAIN PROGRAM #################################################################
  def update
    new_album_directories = Dir[@music_folder + '/*']
    if new_album_directories != @album_directories
      @albums = read_albums(@music_folder)
      @album_directories = new_album_directories
    end
    if !@track_modifying && @track_option == 1
      initialize_album
      @track_option = 0
    end
    @tracks_state.each do |track, liked|
      if liked && !@liked_tracks.include?(track)
        @liked_tracks << track
      elsif !liked && @liked_tracks.include?(track)
        @liked_tracks.delete(track)
      end
    end

    if !@on_a_page
      @current_playlist = nil
    end

  end

  def arrow_hovered?(xcor, ycor)
    return mouse_x >= xcor && mouse_x <= xcor + 96.8 && mouse_y >= ycor && mouse_y <= ycor + 103.2
  end

  def choose
    return mouse_x >= 218 && mouse_x <= 218 + 158 && mouse_y >= 795 && mouse_y <= 795 + 155
  end

  def draw
    background
    if @on_a_page
      if @on_favourites_page
        draw_favourites_page
      elsif @on_albums_page
        draw_albums_page
      elsif @on_songs_page
        draw_songs_page
      end
    else
      @font.draw('Home', 34, 31, ZOrder::UI, 0.66, 0.66, Gosu::Color::WHITE)
      @menu.draw(28, 65 + 42.23 * @main_menu_option, ZOrder::MENU, 1.005, 0.93)
      draw_menu
    end

    if @track_modifying
      draw_page('Options')
      @menu_extended_2.draw(28, 65 + 42.23 * @track_option, ZOrder::UI, 1.005, 0.93)
      draw_track_options(@track_to_modify)
    end

    if @is_playing && @show_playing_track
      draw_playing_track(@current_playing_track)
    end
  end

  def needs_cursor?
    true
  end

  def button_down(id)
    case id
    when Gosu::MsLeft
      if !@on_a_page
        if arrow_hovered?(*UP_ARROW)
          if @main_menu_option > 0
            @main_menu_option -= 1
          end
        end
        if arrow_hovered?(*DOWN_ARROW)
          if @main_menu_option < 2
            @main_menu_option += 1
          end
        end
      end
      
      if choose && !@on_a_page
        @on_a_page = true
        case @main_menu_option
        when 0
          @on_favourites_page = true
        when 1
          @on_albums_page = true
        when 2
          @on_songs_page = true
        end
      end

      if choose && @on_albums_page
        if @page_navigation < 3
          @page_navigation += 1
        end
      elsif choose && (@on_songs_page || @on_favourites_page)
        if @page_navigation < 2
          @page_navigation += 1
        end
      end

      if @on_songs_page
        if !@all_tracks.empty?
          tracks_navigation(@all_tracks.keys, 2)
        end
      elsif @on_favourites_page && !no_liked_tracks?(@tracks_state)
        tracks_navigation(@liked_tracks, 2)
      elsif @on_albums_page && !@albums.nil?
        album_page_control
      else
        @track_start_display, @track_end_display = START_END_DEFAULT
        @track_index = 0
      end

      if @track_modifying
        track_options(@track_to_modify)
      end

      if arrow_hovered?(*LEFT_ARROW) && @is_playing
        @show_playing_track = false
      end

      if mouse_x >= 239 && mouse_x <= 349 && mouse_y >= 648 && mouse_y <= 689
        reset_pages
      end

      if mouse_x >= 71 && mouse_x <= 111 && mouse_y >= 863 && mouse_y <= 890
        if @is_playing
          if @current_track_index - 1 >= 0
            @current_track_index -= 1
            playTrack(@current_track_index, @current_playlist)
          end
        end
      elsif mouse_x >= 480 && mouse_x <= 520 && mouse_y >= 863 && mouse_y <= 890
        if @is_playing
          if @current_track_index + 1 < @current_playlist.length
            @current_track_index += 1
            playTrack(@current_track_index, @current_playlist)
          end
        end
      elsif mouse_x >= 278 && mouse_x <= 318 && mouse_y >= 1065 && mouse_y <= 1095
        if @song.playing?
          @song.pause
        else
          @song.play(false)
        end
      end
    end
  end
end

MusicPlayerMain.new.show if __FILE__ == $0

