require 'test_helper'

class PayDollarTest < Test::Unit::TestCase
  def setup
    @gateway = PayDollarGateway.new(
                 :merchant_id => 'abc123',
                 :success_url => 'http://example.com/success',
                 :fail_url => 'http://example.com/fail',
                 :error_url => 'http://example.com/error'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1020353', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'This card has expired', response.message
    assert_failure response
    assert response.test?
  end

  private

  # NOTE This was written before a proper test account was issued from
  # AsiaPay, so the form of the success response has been extrapolated
  # from the other responses their API returns.
  def successful_purchase_response
    headers = { }
    body = <<-HTML
<HTML><HEAD><TITLE> Payment </TITLE></HEAD>
<script>
function MM_findObj(n, d) { //v3.0
var p,i,x;  if(!d) d=document; if((p=n.indexOf("?"))>0&&parent.frames.length) {
d=parent.frames[n.substring(p+1)].document; n=n.substring(0,p);}
if(!(x=d[n])&&d.all) x=d.all[n]; for (i=0;!x&&i<d.forms.length;i++) x=d.forms[i][n];
for(i=0;!x&&d.layers&&i<d.layers.length;i++) x=MM_findObj(n,d.layers[i].document); return x;
}

function formSubmit(action){
  var form = MM_findObj("pageRedirect");	
  form.submit();
}
</script>
  <body onLoad='javascript:formSubmit();'>
  <form name="pageRedirect" method="post" action="pageRedirect.jsp">
    <input type="hidden" name="masterMerId" value="1" >
    <input type="hidden" name="oId" value="1020353">
    <input type="hidden" name="sessionId" value="516995" >
    <input type="hidden" name="urlRedirect" value="http://example.com/success?Ref=000000000006" >
    <script>
      var rightNow = new Date();
      var jan1 = new Date(rightNow.getFullYear(), 0, 1, 0, 0, 0, 0);
      var temp = jan1.toGMTString();
      var jan2 = new Date(temp.substring(0, temp.lastIndexOf(" ")-1));
      var std_time_offset = (jan1 - jan2) / (1000 * 60 * 60);
      document.write('<input type=hidden name=pcTimeZone value='+std_time_offset+'>');
    </script>
  </form>
  </body>
</html>
HTML

    [200, headers, body]
  end

  def failed_purchase_response
    headers = {
      'location' => ['http://example.com/error?Ref=000000000006&errorMsg=This card has expired&failUrl=http://example.com/fail?Ref=000000000006']
    }
    body = ''

    [302, headers, body]
  end
end
