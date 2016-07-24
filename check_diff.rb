require 'date'
    
def check_standard
    err  = false
    code = 0
    end_date_old = ""
    while line = $stdin.gets do
    	if /^diff --git a\/Analysis\/DB\/(\d+)_price.db b\/Analysis\/DB\/(\d+)_price.db/.match line then
    
    		if err then
    			#$stderr.printf( "Error in %d_price.db\n", code )
                ;
            elsif code != 0 then
                printf( "git add %d_price.db\n", code )
    		end
    
    		code = $1.to_i
    		err = false
    	elsif /^-\s+(end_date|price)='(.*)';$/.match line then
            end_date_old = Date.strptime($2,"%Y-%m-%d") if $1 == "end_date"
    	elsif /^- /.match line then
    		err = true
        elsif /^\+\s*(\d+-\d+-\d+)/.match line then
            if Date.strptime( $1, "%Y-%m-%d" ) < end_date_old then
                err = true
            end
        else 
            ;
    	end
    end
end

def check_loose
    err  = false
    code = 0
    end_date_old = ""
    while line = $stdin.gets do
    	if /^diff --git a\/Analysis\/DB\/(\d+)_price.db b\/Analysis\/DB\/(\d+)_price.db/.match line then
    
    		if err then
    		#	$stderr.printf( "Error in %d_price.db\n", code )
            elsif code != 0 then
                printf( "git add %d_price.db\n", code )
    		end
    
    		code = $1.to_i
    		err = false
    	elsif /^-\s+(end_date|price)='(.*)';$/.match line then
            end_date_old = Date.strptime($2,"%Y-%m-%d") if $1 == "end_date"
    	elsif /^-\s+start_date/.match line then
            err = true
    	elsif /^- /.match line then
    		#err = true
        elsif /^\+\s*(\d+-\d+-\d+)/.match line then
            #if Date.strptime( $1, "%Y-%m-%d" ) < end_date_old then
            #    err = true
            #end
        else 
            ;
    	end
    end

end

if $0 == __FILE__ then
    if ARGV.size == 0 or ARGV[0] == "--standard" then
        check_standard
    elsif ARGV[0] == "--loose" then
        check_loose
    else
        $stderr.puts("Invalid option")
        exit 1
    end
end

