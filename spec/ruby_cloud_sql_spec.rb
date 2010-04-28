require 'rubygems'
require 'spec'
require 'ruby_cloud_sql'
require 'pp'

describe RubyCloudSQL do
  before :all do
    stub_login
    opts = {:login_name => '*******', :password => '*******', :database_name => 'DB', :api_key => '42n84c8db3czd5fma8721b9bi32316cb'}
    @ruby_cloud_sql = RubyCloudSQL.new( opts )
  end

  def stub_login
    @http = mock( Net::HTTP )
    Net::HTTP.stub!( :new ).and_return( @http )
    @http.stub!( :use_ssl= )
    http_get = mock( Net::HTTP::Get )
    Net::HTTP::Get.stub!( :new ).and_return( http_get )
    resp = mock( Net::HTTPResponse )
    resp.stub!( :code ).and_return( "200" )
    resp.stub!( :body ).and_return( "TICKET=R2D23CP0" )
    @http.stub!( :request ).and_return( resp )
  end

  describe "finding data using SQL statements" do
    before :all do
      return_xml_string =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\" ?>
        <response uri=\"/api/vothanic/DB/Sales\" action=\"EXPORT\">
            <result>
                <rows>
                    <row>
                        <column name=\"Customer Name\">Pete Zachriah</column>
                        <column name=\"Sales\">$6,789.43</column>
                        <column name=\"Cost\">$2,744.49</column>
                        <column name=\"Profit (Sales)\">$4,044.94</column>
                    </row>
                    <row>
                        <column name=\"Customer Name\">Thomas Mondrake</column>
                        <column name=\"Sales\">$558.05</column>
                        <column name=\"Cost\">$176.56</column>
                        <column name=\"Profit (Sales)\">$381.49</column>
                    </row>
                </rows>
            </result>
        </response>
      """
      stub_http_request( "200", return_xml_string )
      sql = "select \"Customer Name\",Sales,Cost,\"Profit (Sales)\" from Sales where Region = 'Central'"
      lambda {
        @find_response = @ruby_cloud_sql.zoho_find_by_sql( "DB", "Sales", sql )
      }.should_not raise_error
    end

    it "should return a query result specified by the sql" do
      @find_response.should_not be_nil
      @find_response.should_not be_empty
      @find_response.should ==
        {"rows"=>
          {"row"=>
            [{"column"=>
                [{"name"=>"Customer Name", "content"=>"Pete Zachriah"},
                {"name"=>"Sales", "content"=>"$6,789.43"},
                {"name"=>"Cost", "content"=>"$2,744.49"},
                {"name"=>"Profit (Sales)", "content"=>"$4,044.94"}]},
            {"column"=>
                [{"name"=>"Customer Name", "content"=>"Thomas Mondrake"},
                {"name"=>"Sales", "content"=>"$558.05"},
                {"name"=>"Cost", "content"=>"$176.56"},
                {"name"=>"Profit (Sales)", "content"=>"$381.49"}]}]}}

    end
  end

  describe "adding rows of data in cloud the database" do
    before :all do
      return_create_xml_string =
        """
		  <?xml version=\"1.0\" encoding=\"UTF-8\"?>
		  <response uri=\"/api/vothanic/DB/Sales\" action=\"ADDROW\">
			  <result>
				  <rows>
					  <row>
						  <column name=\"Date\">
							  Jan 01, 2009 12:00:00 AM
						  </column>
						  <column name=\"Region\">
							  South
						  </column>
						  <column name=\"Product Category\">
							  Tobacco
						  </column>
						  <column name=\"Product\">
							  Cigarettes
						  </column>
						  <column name=\"Customer Name\">
							  Smoker
						  </column>
						  <column name=\"Sales\">
							  $500.00
						  </column>
						  <column name=\"Cost\">
							  $400.00
						  </column>
						  <column name=\"Profit (Sales)\">
							  $100.00
						  </column>
					  </row>
				  </rows>
			  </result>
		  </response>
      """
      stub_http_request( "200", return_create_xml_string )
      @row_data = {"Date" => "01 Jan, 2009 00:00:00", "Region" => "South", "Product Category" => "Tobacco", "Product" => "Cigarettes", "Customer Name" => "Smoker", "Sales" => 500, "Cost" => 400, "Profit (Sales)" => 100}

      lambda {
        @row_created = @ruby_cloud_sql.zoho_create( "DB", "Sales", @row_data )
      }.should_not raise_error

      return_find_xml_string =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\" ?>
        <response uri=\"/api/vothanic/DB/Sales\" action=\"EXPORT\">
            <result>
                <rows>
                    <row>
                        <column name=\"Customer Name\">Pete Zachriah</column>
                        <column name=\"Sales\">$6,789.43</column>
                        <column name=\"Cost\">$2,744.49</column>
                        <column name=\"Profit (Sales)\">$4,044.94</column>
                    </row>
                    <row>
                        <column name=\"Customer Name\">Thomas Mondrake</column>
                        <column name=\"Sales\">$558.05</column>
                        <column name=\"Cost\">$176.56</column>
                        <column name=\"Profit (Sales)\">$381.49</column>
                    </row>
                </rows>
            </result>
        </response>
      """
      stub_http_request( "200", return_find_xml_string )
      sql_for_new_row = "SELECT * FROM Sales WHERE #{query_conditions( @row_data )}"

      lambda {
        @add_response = @ruby_cloud_sql.zoho_find_by_sql( "DB", "Sales", sql_for_new_row )
      }.should_not raise_error

    end

    it "should have created a new row of data" do
      @row_created.should == true
    end

    it "should have the correct data for the new row" do
      @add_response.should ==
        {"rows"=>
          {"row"=>
            [{"column"=>
                [{"name"=>"Customer Name", "content"=>"Pete Zachriah"},
                {"name"=>"Sales", "content"=>"$6,789.43"},
                {"name"=>"Cost", "content"=>"$2,744.49"},
                {"name"=>"Profit (Sales)", "content"=>"$4,044.94"}]},
            {"column"=>
                [{"name"=>"Customer Name", "content"=>"Thomas Mondrake"},
                {"name"=>"Sales", "content"=>"$558.05"},
                {"name"=>"Cost", "content"=>"$176.56"},
                {"name"=>"Profit (Sales)", "content"=>"$381.49"}]}]}}

    end
  end

  describe "updating rows of data in the cloud database" do
    before :all do
      return_update_xml_string =
        """
		<?xml version=\"1.0\" encoding=\"UTF-8\"?>
		<response uri=\"/api/vothanic/DB/Sales\" action=\"UPDATE\">
			<criteria>
				((&quot;Customer Name&quot; = &apos;Smoker&apos;))
			</criteria>
			<result>
				<updatedColumns>
					<column>
						Profit (Sales)
					</column>
					<column>
						Sales
					</column>
					<column>
						Cost
					</column>
				</updatedColumns>
			</result>
		</response>

      """
      stub_http_request( "200", return_update_xml_string )
      @new_data = {"Sales" => 800, "Cost" => 600, "Profit (Sales)" => 200}

      lambda {
        @row_updated = @ruby_cloud_sql.zoho_update( "DB", "Sales", "(\"Customer Name\" = 'Smoker')", @new_data )
      }.should_not raise_error

      return_find_xml_string =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\" ?>
        <response uri=\"/api/vothanic/DB/Sales\" action=\"EXPORT\">
            <result>
                <rows>
                    <row>
                        <column name=\"Customer Name\">Pete Zachriah</column>
                        <column name=\"Sales\">$6,789.43</column>
                        <column name=\"Cost\">$2,744.49</column>
                        <column name=\"Profit (Sales)\">$4,044.94</column>
                    </row>
                    <row>
                        <column name=\"Customer Name\">Thomas Mondrake</column>
                        <column name=\"Sales\">$558.05</column>
                        <column name=\"Cost\">$176.56</column>
                        <column name=\"Profit (Sales)\">$381.49</column>
                    </row>
                </rows>
            </result>
        </response>
      """
      stub_http_request( "200", return_find_xml_string )
      sql_for_updated_row = "SELECT * FROM Sales WHERE #{query_conditions( @new_data )}"

      lambda {
        @update_response = @ruby_cloud_sql.zoho_find_by_sql( "DB", "Sales", sql_for_updated_row )
      }.should_not raise_error
    end

    it "should have updated the row with new data" do
      @row_updated.should == true

    end

    it "should have the new data in the row" do
      @update_response.should ==
        {"rows"=>
          {"row"=>
            [{"column"=>
                [{"name"=>"Customer Name", "content"=>"Pete Zachriah"},
                {"name"=>"Sales", "content"=>"$6,789.43"},
                {"name"=>"Cost", "content"=>"$2,744.49"},
                {"name"=>"Profit (Sales)", "content"=>"$4,044.94"}]},
            {"column"=>
                [{"name"=>"Customer Name", "content"=>"Thomas Mondrake"},
                {"name"=>"Sales", "content"=>"$558.05"},
                {"name"=>"Cost", "content"=>"$176.56"},
                {"name"=>"Profit (Sales)", "content"=>"$381.49"}]}]}}
    end
  end

  describe "deleting rows of data in the cloud database" do
    before :all do
      return_delete_xml_string =
        """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <response uri=\"/api/vothanic/DB/Sales\" action=\"DELETE\">
          <criteria>
            (&quot;Customer Name&quot; = &apos;Smoker&apos;)
          </criteria>
          <result>
            <message>
              Deleted Rows
            </message>
          </result>
        </response>
      """
      stub_http_request( "200", return_delete_xml_string )

      lambda {
        @row_deleted = @ruby_cloud_sql.zoho_delete( "DB", "Sales", "(\"Customer Name\" = 'Smoker')" )
      }.should_not raise_error
    end

    it "should have deleted a specified row of data" do
      @row_deleted.should == true
    end
  end

  describe "migrating data to an existing table in the cloud database" do
    before :all do
      return_migrate_xml_string =
        """
          <?xml version=\"1.0\" encoding=\"UTF-8\" ?>
          <response uri=\"/api/vothanic/DB/test\" action=\"IMPORT\">
              <result>
                  <importSummary>
                      <importType>TRUNCATEADD</importType>
                      <totalColumnCount>9</totalColumnCount>
                      <selectedColumnCount>9</selectedColumnCount>
                      <totalRowCount>10</totalRowCount>
                      <successRowCount>10</successRowCount>
                      <warnings>0</warnings>
                      <importOperation>updated</importOperation>
                  </importSummary>
                  <columnDetails>
                      <column datatype=\"Positive Number\">id</column>
                      <column datatype=\"Date\">Date</column>
                      <column datatype=\"Plain Text\">Region</column>
                      <column datatype=\"Plain Text\">Product Category</column>
                      <column datatype=\"Plain Text\">Product</column>
                      <column datatype=\"Plain Text\">Customer Name</column>
                      <column datatype=\"Currency\">Sales</column>
                      <column datatype=\"Currency\">Cost</column>
                      <column datatype=\"Currency\">Profit (Sales)</column>
                  </columnDetails> <!-- The first 100 errors are alone sent -->
                  <importErrors>  </importErrors>
              </result>
          </response>
      """
      stub_http_request( "200", return_migrate_xml_string )

      lambda {
        @data_migrated = @ruby_cloud_sql.zoho_migrate( "DB", "Sales", "#{File.dirname(__FILE__)}/test.csv" )
      }.should_not raise_error
    end

    it "should have migrated data in csv file to cloud database" do
      @data_migrated.should == true
    end
  end

  def stub_http_request( return_code, return_body )
    resp = mock( Net::HTTPResponse )
    resp.stub!( :code ).and_return( return_code )
    resp.stub!( :body ).and_return( return_body )
    @http.stub!( :send_request ).and_return( resp )
  end

  def query_conditions( data )
    pairs = []
    data.each do |key, value|
      pairs << "\"#{key}\"='#{value}'"
    end

    query_string = "#{pairs.join(" AND ")}"
  end
end