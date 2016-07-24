# -*- coding: utf-8 -*-

class PriceDB
    attr_reader :bi
    
    # 証券コードcodeの DBファイルを読み込む。
    # [code] 証券コード、4桁の整数
    def initialize( code, dbdir )
      @bi = {}
      @DB = dbdir
      read_basic_info( code )
    end

    # dataを初期化する関数
    def clear( code )
	@bi = {}
	File.unlink format( "#{@DB}/%04d_price.db", code )
    end 

    # 証券コードcodeの DBファイルを読み込む。
    # [code] 証券コード、4桁の整数
    def read_basic_info( code )
        file = format( "#{@DB}/%04d_price.db", code )
        if File.exists?( file )
            f = File.open( file, "r:UTF-8" )
            
            in_section = false
            while line = f.gets do 
                if /section\s+basic_info\s*{/.match line then 
                    in_section = true
                elsif in_section and /(code|ext|name|unit|start_date|end_date|price)=\'(.*)\';/.match line then
                    if $1 == "start_date" or $1 == "end_date" then
                        if $2 != "" then
                            @bi[$1] = Date.strptime( $2, "%Y-%m-%d" )
                        end
                    else
                        @bi[$1] = $2
                    end
                elsif in_section and /\s*}\s*;/.match line
                    break
                end
            end
        else
            @bi = {}
        end
    end

    # DBファイルの価格データを読み込む。
    def read_price_info
        file = format( "#{@DB}/%04d_price.db", code )
        if File.exists?( file )
            f = File.open( file, "r:UTF-8" )
            in_section = false
            while line = f.gets do
                if /section\s+price\s*{/.match line then 
                    in_section = true
                elsif /};/.match( line ) then
                    in_section = false
                elsif in_section then
                    @pi.push( line )
                end
            end
        else
            @pi = []
        end
    end

    # DBファイルの分割データを読み込む。
    def read_split_info
        file = format( "#{@DB}/%04d_price.db", code )
        if File.exists?( file )
            f = File.open( file, "r:UTF-8" )
            in_section = false
            while line = f.gets do
                if /section\s+split\s*{/.match line then 
                    in_section = true
                elsif /};/.match( line ) then
                    in_section = false
                elsif in_section then
                    @si.push( line )
                end
            end
        else
            @si = []
        end
    end

    # 基本情報を追加する
    def add_basicInfo( bi )
        updated = false
        if @bi["name"] == nil then
            @bi["name"] = bi["name"]
            updated = true
        elsif @bi["name"] != bi["name"] then
            printf("company name changed %s to %s\n", @bi["name"], bi["name"] )
            @bi["name"] = bi["name"]
            updated = true
        end

        if @bi["unit"] == nil then
            @bi["unit"] = bi["unit"]
            updated = true
        elsif @bi["unit"].to_i != bi["unit"] then
            printf("unit changed %d to %d\n", @bi["unit"], bi["unit"] )
            @bi["unit"] = bi["unit"]
            updated = true
        end
    end

    # 価格データを追加する
    #   [data] 価格データ.古い順にならんでいる前提
    def add_price( data )
        data.delete_if { |dt|
            date = Date.strptime( dt["d"], "%Y-%m-%d" )
            if @bi["start_date"] == nil and @bi["end_date"] == nil then
                false
            elsif @bi["start_date"] == nil and date <= @bi["end_date"] then
                false
            elsif @bi["start_date"] <= date and date <= @bi["end_date"] then
                true
            else
                false
            end
        }
        st = nil
        if data != [] then
            if @pi == nil then
                @pi = Array.new
                read_price_info
            end

            strs = []
            data.each do |dt|
                str = format( "  %s,%d,%d,%d,%d,%d;\n",dt["d"],dt["start"],dt["high"],dt["low"],dt["close"],dt["to"] )
                strs.push( str )
            end

            if @bi["end_date"] == nil or Date.strptime( data[data.size()-1]["d"], "%Y-%m-%d" ) > @bi["end_date"] then
                @pi = @pi.concat( strs )
                @bi["end_date"] = Date.strptime( data[data.size()-1]["d"], "%Y-%m-%d" )
                @bi["price"] = data[data.size-1]["close"]
                if @bi["start_date"] == nil then
                    @bi["start_date"] = Date.strptime( data[0]["d"], "%Y-%m-%d" )
                end
            elsif @bi["start_date"] == nil or Date.strptime( data[0]["d"], "%Y-%m-%d" ) < @bi["start_date"] then
                @pi = strs.concat( @pi )
                @bi["start_date"] = Date.strptime( data[0]["d"], "%Y-%m-%d" )
            end
            return true
        else
            return false
        end
    end


    # 分割データを追加する
    #   [data] 価格データ.古い順にならんでいる前提
    def add_split( data )
        data.delete_if { |dt|
            date = Date.strptime( dt["d"], "%Y-%m-%d" )
            s0 = 0
            se = 0
            if @si != nil then
                @si[@si.size()-1].split(/[\s,]+/)
                s0 = Date.strptime( @si[0].split(/[\s,]+/)[1], "%Y-%m-%d")
                se = Date.strptime( @si[@si.size()-1].split(/[\s,]+/)[1], "%Y-%m-%d")
            end

            if @si == nil then
                false
            elsif s0 > date or se < date then
                false
            else
                true
            end
        }
        if data != [] then
            if @si == nil then
                @si = Array.new
                read_split_info
            end

            strs = []
            data.each do |dt|
                str = format( "  %s,%f;\n",dt["d"],dt["rate"] )
                strs.push( str )
            end

            p strs
            p @si
            if @si == [] then
                @si = strs
            elsif Date.strptime( data[0]["d"], "%Y-%m-%d" ) > Date.strptime( @si[@si.size()-1].split(/[\s,]+/)[1], "%Y-%m-%d") then 
                @si = @si + strs
            else
                @si = strs + @si
            end
            p @si
            return true
        else
            return false
        end
    end

    # 証券コードを返す関数
    #   Tag <price_data>のattribute 'code'を返す
    def code
        @bi["code"].to_i
    end

    # 証券コード + extension を返す関数
    #   Tag <price_data>のattribute 'code'を返す
    def code_ext
        if @db.elements["price_data"].attributes["ext"] != nil then
            return @db.elements["price_data"].attributes["code"] + @db.elements["price_data"].attributes["ext"]
        else
            return nil
        end
    end

    # extension を返す関数
    #   Tag <price_data>のattribute 'code'を返す
    def ext
        return @db.elements["price_data"].attributes["ext"]
    end

    # extension をセットする関数
    def set_ext( ext )
        @bi["ext"] = ext
    end
        
    
    # 企業名を返す関数
    #   Tag <price_data>のattribute 'code'を返す
    def name
        @db.elements["price_data"].attributes["name"]
    end

    # 
    #
    # def dates
    #     return @price_data.sort
    # end
    

    def write_db
        if @pi == nil then
            @pi = Array.new
            read_price_info
        end

        if @si == nil then
            @si = Array.new
            read_split_info
        end

        f = File.open( format( "#{@DB}/%04d_price.db", code ), "w:UTF-8" )
        f.print to_str
        f.close
    end


    # DBの内容をstringにする関数。
    def to_str
        str = ""
        # basic info
        str += "section basic_info {\n"
        [ "code", "ext", "name", "unit", "start_date", "end_date", "price" ].each do |e|
            str += format( "  %s='%s';\n", e, @bi[e] )
        end
        str += "};\n"

        # price info
        str += "section price {\n"
        @pi.each do |pp|
            str += pp
        end
        str += "};\n"

        # basic info
        str += "section split {\n"
        @si.each do |ss|
            str += ss
        end
        str += "};\n"

        return str
    end


end
