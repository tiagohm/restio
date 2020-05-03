import 'package:http_parser/http_parser.dart';
import 'package:restio/src/common/helpers.dart';
import 'package:test/test.dart';

void main() {
  test('Parsing www-authenticate header', () {
    var challenges = AuthenticationChallenge.parseHeader(
      'Bearer realm="service", error="invalid_token",'
      ' error_description="The access token is invalid or has expired"',
    );

    expect(challenges[0].scheme, 'bearer');
    expect(challenges[0].parameters['realm'], 'service');
    expect(challenges[0].parameters['error'], 'invalid_token');
    expect(challenges[0].parameters['error_description'],
        'The access token is invalid or has expired');

    challenges = AuthenticationChallenge.parseHeader('OAuth realm="Example",'
        ' oauth_consumer_key="0685bd9184jfhq22",'
        ' oauth_token="ad180jjd733klru7",'
        ' oauth_signature_method="HMAC-SHA1",'
        ' oauth_signature="wOJIO9A2W5mFwDgiDvZbTSMK%2FPY%3D",'
        ' oauth_timestamp="137131200",'
        ' oauth_nonce="4572616e48616d6d65724c61686176",'
        ' oauth_version="1.0",'
        ' Digest realm="testrealm@host.com",'
        ' qop="auth,auth-int",'
        ' nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093",'
        ' opaque="5ccc069c403ebaf9f0171e9517f40e41"');

    expect(challenges[0].scheme, 'oauth');
    expect(challenges[0].parameters['realm'], 'Example');
    expect(challenges[0].parameters['oauth_version'], '1.0');
    expect(challenges[1].scheme, 'digest');
    expect(challenges[1].parameters['realm'], 'testrealm@host.com');
    expect(challenges[1].parameters['qop'], 'auth,auth-int');
    expect(
      challenges[1].parameters['nonce'],
      'dcd98b7102dd2f0e8b11d0f600bfb0c093',
    );
    expect(
      challenges[1].parameters['opaque'],
      '5ccc069c403ebaf9f0171e9517f40e41',
    );
  });

  test('Encode Form', () {
    var res = canonicalizeToString(
      " \"':;<=>+@[]^`{}|/\\?#&!\$(),~",
      formEncodeSet,
      plusIsSpace: true,
    );
    expect(
      res,
      '%20%22%27%3A%3B%3C%3D%3E%2B%40%5B%5D%5E%60'
      '%7B%7D%7C%2F%5C%3F%23%26%21%24%28%29%2C%7E',
    );

    res = canonicalizeToString('円', formEncodeSet, plusIsSpace: true);
    expect(res, '%E5%86%86');

    res = canonicalizeToString('£', formEncodeSet, plusIsSpace: true);
    expect(res, '%C2%A3');

    res = canonicalizeToString('\n\r\t', formEncodeSet, plusIsSpace: true);
    expect(res, '%0A%0D%09');
  });
}
