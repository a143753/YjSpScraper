# -*- coding: utf-8 -*-

require 'kconv'
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'date'

module YahooParser

  Extentions = [ '.t', '.q', '.o', '.n', '.s', '.f' ]


    PriceTable = {
        "日付" => 'd',
        "始値" => 'start',
        "終値" => 'close', 
        "高値" => 'high', 
        "安値" => 'low', 
        "出来高" => 'to', 
        "調整後終値*" => nil }

    # yahoo.co.jpから株価時系列データを取得する関数
    # [code] 証券コード、4桁の整数
    # Yahoo!は以下の形式で 50件ずつ取得できる
    # http://table.yahoo.co.jp/t?s=6758.t&a=9&b=22&c=2010&d=12&e=24&f=2010&g=d&q=t&y=0&z=6758.t&x=.csv
    #  f/d/e から c/a/b の時系列データのうち 1番目から (最大)50件
    # "http://table.yahoo.co.jp/t?s=6758.t&a=9&b=22&c=2010&d=12&e=24&f=2010&g=d&q=t&y=50&z=6758.t&x=.csv"
    #  f/d/e から c/a/b の時系列データのうち 51番目から (最大)50件
    # yがoffsetになる
    def getPrice( code, ext, date )
        price = []
        split = []
        tmp = {}
        key = []

        f = date.year
        e = date.day
        d = date.month

        c = ( date - 49 ).year
        b = ( date - 49 ).day
        a = ( date - 49 ).month
        #http://info.finance.yahoo.co.jp/history/?code=1301.T&sy=2014&sm=6&sd=12&ey=2014&em=7&ed=12&tm=d
        dir = format( "/history/?code=%s&sy=%d&sm=%d&sd=%d&ey=%d&em=%d&ed=%d&tm=d", code, c, a, b, f, d, e )

        begin
            doc = Nokogiri( open( "http://info.finance.yahoo.co.jp" + dir ).read.toutf8 )
            print "http://info.finance.yahoo.co.jp" + dir, "\n"
        rescue OpenURI::HTTPError => the_error
            if the_error.io.status[0] == 999 then
                puts "999 Error"
                exit 1
            else
                puts the_error.io.status[0]
                return [], []
            end
        rescue EOFError => the_error
            # 上場廃止直後でデータが一部残っているときにEOFErrorが返る
            # ことがあるよう。
            puts the_error
            return [], []
        end

        ( doc/'table').each{ |elem|
            if (elem/'tr')[0].inner_text.gsub(/\n/,"") == "日付始値高値安値終値出来高調整後終値*" then
                idx = 0
                (elem/'th').each { |th|
                    if PriceTable.keys.include? th.inner_text then
                        key[idx] = PriceTable[th.inner_text.toutf8] if PriceTable[th.inner_text.toutf8] != nil
                    else
                        $stderr.print( "未知の列名 ", th.inner_text, "\n" )
                    end
                    idx += 1
                }

                (elem/'tr').each do |tr|
                    if (tr/'td').size == 0 then
                        ;
                    elsif (tr/'td').size == 7 then
                        ( 0 .. 5 ).each do |i|
                            if key[i] == 'd' then
                                /(\d+)年(\d+)月(\d+)日/.match( (tr/'td')[i].inner_text )
                                tmp[key[i]] = Date.new( $1.to_i, $2.to_i, $3.to_i ).to_s
                            else
                                tmp[key[i]] = (tr/'td')[i].inner_text.tr( ",", "" ).to_i
                            end
                        end
                        price.push( tmp.dup )
                    elsif (tr/'td').size == 2 then
                        if /分割: ([\d\.]+)株 -> ([\d\.]+)株/.match( (tr/'td')[1].inner_text ) then # expected
                            rate = $2.to_f / $1.to_f
                            /(\d+)年(\d+)月(\d+)日/.match( (tr/'td')[0].inner_text )
                            split.push( { 'd' => Date.new( $1.to_i, $2.to_i, $3.to_i ).to_s, 'rate' => rate } )
                        else
                            raise format( "未知のフォーマット %s\n", tr.inner_text )
                        end
                    else
                        raise format( "未知のフォーマット %s\n", tr.inner_text )
                    end
                end
            end


            # if elem.attribute('bgcolor') and elem.attribute('bgcolor').value == "#eeeeee" then
            #     idx = 0
            #     (elem/'th').each { |th|
            #         if PriceTable.keys.include? th.inner_text then
            #             key[idx] = PriceTable[th.inner_text.toutf8] if PriceTable[th.inner_text.toutf8] != nil
            #         else
            #             $stderr.print( "未知の列名 ", th.inner_text, "\n" )
            #         end
            #         idx += 1
            #     }
            # elsif elem.attribute('bgcolor') and elem.attribute('bgcolor').value == "#ffffff" then
            #     if ( (elem/'td').size == 7) then # expected
            #         ( 0 .. 5 ).each do |i|
            #             if key[i] == 'd' then
            #                 /(\d+)年(\d+)月(\d+)日/.match( (elem/'td')[i].inner_text )
            #                 tmp[key[i]] = Date.new( $1.to_i, $2.to_i, $3.to_i ).to_s
            #             else
            #                 tmp[key[i]] = (elem/'td')[i].inner_text.tr( ",", "" ).to_i
            #             end
            #         end
            #         price.push( tmp.dup )
            #     elsif ( (elem/'td').size == 2 ) then
            #         if /分割: ([\d\.]+)株 -> ([\d\.]+)株/.match( (elem/'td')[1].inner_text ) then # expected
            #             rate = $2.to_f / $1.to_f
            #             /(\d+)年(\d+)月(\d+)日/.match( (elem/'td')[0].inner_text )
            #             split.push( { 'd' => Date.new( $1.to_i, $2.to_i, $3.to_i ).to_s, 'rate' => rate } )
            #         else
            #             raise format( "未知のフォーマット %s\n", elem.inner_text )
            #         end
            #     else
            #         raise format( "未知のフォーマット %s\n", elem.inner_text )
            #     end
            # elsif elem.attribute('bgcolor') and elem.attribute('bgcolor').value == "" then # 
            #     if /この検索期間の価格データはありません。\n期間をご確認ください。/.match( elem.inner_text ) then
            #         # finish
            #         print( "Getting #{code} data finished\n" )
            #         break
            #     else
            #         # $stderr.printf( "未知のフォーマット \"%s\"\n", elem.inner_text )
            #     end
            # end
        }

        return price, split
    end

    def getBasicInfo( code, ext )

        rtn = Hash.new

        # Yahoo!の株式詳細ページより売買単元を取得する

        url = format( "http://stocks.finance.yahoo.co.jp/stocks/detail/?code=%04d%s", code, ext )
        begin
            doc = Nokogiri( open( url ).read.toutf8 )
            #print url, "\n"
        rescue OpenURI::HTTPError => the_error
            puts the_error.io.status[0]
            return rtn
        rescue EOFError => the_error
            # 上場廃止直後でデータが一部残っているときにEOFErrorが返る
            # ことがあるよう。
            puts the_error
            return rtn
        end

        # 企業名
        if (doc/'title')[0].inner_text.sub( /【.*/, "" ) != "Yahoo!ファイナンス" then
            rtn["name"] = (doc/'title')[0].inner_text.sub( /【.*/, "" )
        else
            return rtn
        end

        # 単元
        ( doc/'dl' ).each {|elem|
            if (elem/'dt').size >= 1 then
                if (elem/'dt')[0].inner_text == "単元株数\n取引の基準となる株数" then
                    if (elem/'dd')[0].inner_text == "---株" then
                        rtn["unit"] = 1
                    else 
                        rtn["unit"] = (elem/'dd')[0].inner_text.tr(",","").sub( /(\d+)株/, '\1' ).to_i
                    end
                elsif (elem/'dt')[0].inner_text == "売買単位\nETFを購入・売却するときの単位" then
                    if (elem/'dd')[0].inner_text == "---株" then
                        rtn["unit"] = 1
                    else 
                        rtn["unit"] = (elem/'dd')[0].inner_text.tr(",","").sub( /(\d+)株/, '\1' ).to_i
                    end
                end
            end
        }

        return rtn 
    end

end

