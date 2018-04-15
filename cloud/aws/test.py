# AWS Version 4 signing example

# EC2 API (DescribeRegions)

# See: http://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html
# This version makes a GET request and passes the signature
# in the Authorization header.
import sys, os, base64, datetime, hashlib, hmac 
import requests # pip install requests
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("service")
parser.add_argument("version")
parser.add_argument("authmethod")
parser.add_argument("method")
parser.add_argument("endpoint")
parser.add_argument("action")
args = parser.parse_args()

endpoint = 'https://' + endpoint
request_parameters = 'Action=' + action + '&Version=' + version

# Key derivation functions. See:
# http://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html#signature-v4-examples-python
def sign(key, msg):
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()

def getSignatureKey(key, dateStamp, regionName, serviceName):
    kDate = sign(('AWS4' + key).encode('utf-8'), dateStamp)
    kRegion = sign(kDate, regionName)
    kService = sign(kRegion, serviceName)
    kSigning = sign(kService, 'aws4_request')
    return kSigning

# Read AWS access key from env. variables or configuration file. Best practice is NOT
# to embed credentials in code.
access_key = os.environ.get('AWS_ACCESS_KEY_ID')
secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
region = os.environ.get('DEFAULT_REGION')

if access_key is None or secret_key is None:
    print 'No access key is available.'
    sys.exit()

if region is None:
    region = 'us-east-1'

# Create a date for headers and the credential string
t = datetime.datetime.utcnow()
amzdate = t.strftime('%Y%m%dT%H%M%SZ')
datestamp = t.strftime('%Y%m%d') # Date w/o time, used in credential scope
canonical_uri = '/' 
canonical_querystring = request_parameters
canonical_headers = 'host:' + host + '\n' + 'x-amz-date:' + amzdate + '\n'
signed_headers = 'host;x-amz-date'
payload_hash = hashlib.sha256('').hexdigest()
canonical_request = method + '\n' + canonical_uri + '\n' + canonical_querystring + '\n' + canonical_headers + '\n' + signed_headers + '\n' + payload_hash
algorithm = 'AWS4-HMAC-SHA256'
credential_scope = datestamp + '/' + region + '/' + service + '/' + 'aws4_request'
string_to_sign = algorithm + '\n' +  amzdate + '\n' +  credential_scope + '\n' +  hashlib.sha256(canonical_request).hexdigest()
signing_key = getSignatureKey(secret_key, datestamp, region, service)
signature = hmac.new(signing_key, (string_to_sign).encode('utf-8'), hashlib.sha256).hexdigest()
authorization_header = algorithm + ' ' + 'Credential=' + access_key + '/' + credential_scope + ', ' +  'SignedHeaders=' + signed_headers + ', ' + 'Signature=' + signature
headers = {'x-amz-date':amzdate, 'Authorization':authorization_header}
request_url = endpoint + '?' + canonical_querystring

print '========================================='
print 'canonical_uri = ' + canonical_uri
print 'canonical_querystring = ' + canonical_querystring
print 'canonical_headers = ' + canonical_headers
print 'signed_headers = ' + signed_headers
print 'payload_hash = ' + payload_hash
print 'canonical_request = ' + canonical_request
print 'algorithm = ' + algorithm
print 'credential_scope = ' + credential_scope
print 'string_to_sign = ' + string_to_sign
print 'signing_key = ' + signing_key
print 'signature = ' + signature + '\n'
print 'authorization_header = ' + authorization_header
print 'headers: x-amz-date:' + amzdate + ', Authorization:' + authorization_header
print 'request_url = ' + request_url
