# -*- coding: utf-8 -*-

require 'YahooParser.rb'
include YahooParser
require 'PriceDB'

def parse_opt( argv )
  opt = {
    "code_from" 	=> 0,
    "code_to" 		=> 9999,
    "dbdir"             => "../DB",
    "get_alldata" 	=> false,
    "force" 		=> false
  }
  while argv.size >= 1 do
    case argv[0]
        
    when "--code"
      /(\d+)?:(\d+)?/.match( argv[1] )
      opt["code_from"] = $1.to_i if $1 != nil
      opt["code_to"  ] = $2.to_i if $2 != nil
    when "--dbdir"
      opt["dbdir"] = argv[1]
    when "--get_alldata"
      opt["get_alldata"] = true
    when "--force"
      opt["force"] = true
    end
    argv.shift
  end
  return opt
end

if $0 == __FILE__ then

  opt = parse_opt( ARGV )

  if opt["force"] == false then
    codes = File.open( "#{opt["dbdir"]}/code" ).read.split("\n")
  else 
    codes = ( 1000 .. 9999 ).to_a
  end

  printf( "Getting data from %d to %d ...\n", opt["code_from"], opt["code_to"] )

  codes.each do |c|
    
    code = c.to_i

    if code < opt["code_from"] then
      next
    elsif opt["code_to"] < code then
      break
    end

    date = Date.today
    db = PriceDB.new( code, opt["dbdir"] )
    if opt["get_alldata"] then
      db.clear code
    end

    if db.bi["code"] == nil then
      db.bi["code"] = code;
    end

    from_day = db.bi["start_date"]
    to_day = db.bi["end_date"]
    
    updated = false

    ext_unknown = true
    if db.bi["ext"] != nil then
      ext = db.bi["ext"]
      ext_unknown = false
    end
    
    # 基本情報の取得
    bi = {}
    if ( ext_unknown ) then
      Extentions.each do |e|
        bi = YahooParser.getBasicInfo( code, e )
        if bi != {}
          ext_unknown = false
          ext = e
          db.set_ext( e )
          break
        end
      end
    elsif
      bi = YahooParser.getBasicInfo( code, ext )
    end

    if bi == {} then
      next
    end

    updated |= db.add_basicInfo( bi )

    # 価格データの取得
    while true do
      if (to_day != nil) and (date < to_day) then
        # 既取得データより過去データは取得しない
        break
      end

      #            if to_day == nil or  from_day == nil or ( ( date > to_day or date < from_day ) and date.cwday != 6 and date.cwday != 7 and !date.is_holiday? ) then
      if true then
        printf( "Getting price data of %d til %s...\n", code, date.to_s )
        
        price = []
        split = []
        if ext_unknown then
          Extentions.each do |e|
            price, split = YahooParser.getPrice( code, e, date )
            if price.size != 0 then
              ext_unknown = false
              ext = e
              db.set_ext( e )
              break
            end
          end
        else
          price, split = YahooParser.getPrice( code, ext, date )
        end
        
        printf( "Got price data from %s to %s\n", price[0]["d"], price[price.size-1]["d"] ) if ( price.size >= 1 )
        break if price.size == 0

        updated |= db.add_price price.reverse
        db.add_split split.reverse

        date = Date.strptime( price[price.size-1]["d"], "%Y-%m-%d" ) - 1
      #sleep 5
      else
        date -= 1
        # 現状、Yahooは1983年以降のデータしか持っていない
        if date <= Date.new( 1982, 12, 31 ) then
          break
        end
      end
    end
    db.write_db if updated
    sleep 10
  end
end
