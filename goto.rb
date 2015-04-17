require 'sinatra/base'
require 'active_record'
require 'active_support'
require 'active_support/core_ext'
require 'slim'
require_relative 'bbs_reader'

class Goto < Sinatra::Base
  before do
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'db/goto.db')
  end

  after do
    ActiveRecord::Base.connection.close
  end
  # -------------------------------------------------------------

  get '/' do
    slim :top
  end

  # * クエリ構成用のURL
  #   http://goto.luna.ddns.vc/s/game/48538/
  # * ジャンプ用のURL
  #   http://goto.luna.ddns.vc/s/game/48538/current            → "34"
  #   http://goto.luna.ddns.vc/s/game/48538/current?t=朗読配信 → "朗読配信1"
  #   http://goto.luna.ddns.vc/s/game/48538/current?t=参加表明&ng=避難所

  # 慣習として二重にスレッドが立った場合 レスの多い方
  # select: contains t, numbered, stop == false
  # sort: min(number), max(res)

  def numbered?(str)
    str =~ /[0-9０１２３４５６７８９]+/ ? true : false
  end

  def number(str)
    str.tr('０１２３４５６７８９', '0-9')
    str =~ /[0-9]+/ ? $1.to_i : raise
  end
  
  def find(threads, t, ng)
    threads.select { |thread|
      (t.blank? ? true : thread.title.include?(t)) &&
      (ng.blank? ? true: !thread.title.include?(ng)) &&
      numbered?(thread.title) &&
      thread.last < 1000
    }.sort { |a,b|
      tmp = number(a.title) <=> number(b.title)
      if tmp == 0
        b.last <=> a.last
      else
        tmp
      end
    }.first
  end
  
  get '/s/:category/:board_id/test' do |category, board_id|
    board = Bbs::C板.new(category, board_id)
    hit = find(board.threads, params['t'], params['ng'])
    slim :build, locals: { category: category, board_id: board_id, hit: hit }
  end

  get '/s/:category/:board_id/current' do |category, board_id|
    board = Bbs::C板.new(category, board_id)
    hit = find(board.threads, params['t'], params['ng'])
    if hit
      redirect hit.html_url
    else
      halt 404, "該当するスレッドはありません。掲示板: #{board.url}"
    end

  end

end

