/**
 * Script for Zabbix that recursively gets the total size of all files via WebDAV.
 * To use the script, you need to set the following macros:
 * @param {$WEBDAV.HOST} - server name/ip
 * @param {$WEBDAV.PORT} - server port (443 by default)
 * @param {$WEBDAV.USER} - username
 * @param {$WEBDAV.PASSWORD} - password
 * @param {$WEBDAV.PATH} - path to folder ("/" by default)
 * @returns total number of bytes
 * @author Green FiLin <me@zfilin.org.ua>
 */

function insideTag(text, tagName) {
  var startPos = text.indexOf(tagName + "/>");
  if ( startPos >= 0 ) return "";
  var startPos = text.indexOf(tagName + ">");
  if ( startPos < 0 ) return "";
  var endPos = text.indexOf("<", startPos);
  if ( endPos < 0 ) return "";
  return text.substring( startPos + tagName.length + 1, endPos );
}

function getAllFilesSize(pathUrl)
{

  var requestBody = '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns"><d:prop><d:getcontentlength /><d:getcontenttype /></d:prop></d:propfind>';

  var requestHttp = new HttpRequest();
  requestHttp.addHeader('Depth: 1');
  var responseHttp = requestHttp.customRequest('PROPFIND', 'https://{$WEBDAV.USER}:{$WEBDAV.PASSWORD}@{$WEBDAV.HOST}:{$WEBDAV.PORT}' + pathUrl, requestBody);

  if ( !responseHttp.includes('<?xml') ) {
    return 0;
  }

  responseHttp = XML.query(responseHttp, '//*[local-name()="response"]/*[local-name()="href"]/..');

  var files = [];
  
  do {
    var startPos = responseHttp.indexOf( 'href>' );
    if ( startPos < 0 ) break;
    var midPos = responseHttp.indexOf( 'href>', startPos+1 );
    if ( midPos < 0 ) break;
    var endPos = responseHttp.indexOf( 'href>', midPos+1 );
    if ( endPos < 0 ) endPos = responseHttp.length;
    
    var response = responseHttp.substring(startPos, endPos);
    
    var item = {};
    item['href'] = insideTag(response, "href");
    item['type'] = insideTag(response, "getcontenttype");
    item['size'] = insideTag(response, "getcontentlength");
    
    files.push(item);
    responseHttp = responseHttp.substr(endPos);
  } while (true);

  var result = 0;
  
  files.forEach(function (file) {
    if ( file['type'].includes('directory') ) {
      if ( file['href'] != pathUrl ) result += getAllFilesSize( file['href'] );
    } else {
      result += parseInt( file['size'] );
    }
  });

  return result;

}

return getAllFilesSize("{$WEBDAV.PATH}");