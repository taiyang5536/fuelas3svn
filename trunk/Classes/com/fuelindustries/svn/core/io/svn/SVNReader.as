package com.fuelindustries.svn.core.io.svn 
{
	import com.fuelindustries.lang.Character;
	import com.fuelindustries.svn.core.io.SVNRepository;

	import flash.errors.EOFError;
	import flash.utils.ByteArray;

	/**
	 * @author julian
	 */
	public class SVNReader 
	{
		private static var  DEAFAULT_ERROR_TEMPLATE:String = "nssn";
    	private static var  DEFAULT_TEMPLATE:String = "wl";
    	private static var  UTF8_CHARSET_STRING:String = "UTF-8";
		
		 public static function getLong( items:Array, index:int ):int 
		 {
	        if (items == null || index >= items.length ) 
	        {
	            return -1;
	        }
        	
        	var item:Object = items[index];
        	if(item is int) 
        	{
            	return int( item );
        	}
        	return -1;
    	}

		public static function getBytes(items:Array, index:int ):ByteArray
		{
			if (items == null || index >= items.length ) 
			{
            	return null;
        	}
			
			var item:Object = items[ index ];
			
			if( item is ByteArray )
			{
				return( item as ByteArray );
			}
			else if( item is String )
			{
				var ba:ByteArray = new ByteArray();
				ba.writeUTFBytes( item as String );
				ba.position = 0;
				return( ba );
			}
						
			return null;
		}

		public static function parse( ba:ByteArray, template:String, values:Array):Array
		{
			var readItems:Array = readTuple(ba, DEFAULT_TEMPLATE);
			var word:String = getString(readItems, 0);
        	var list:Array = getItemList(readItems, 1);

        	if( "success" == word ) 
        	{
            	return parseTupleArray(template, list, values);
        	} 
        	else if ("failure" == word ) 
        	{
            	//TODO implement errors
            	//handleFailureStatus(list);
            	throw new Error( "failed" );
        	} 
        	else 
        	{
            	//TODO
            	//SVNErrorMessage err = SVNErrorMessage.create(SVNErrorCode.RA_SVN_MALFORMED_DATA, "Unknown status ''{0}'' in command response", word);
            	//SVNErrorManager.error(err, SVNLogType.NETWORK);
            	throw new Error( "Unknown status " + word + " in command response" );
        	}
        	return null;
		}

		private static function getItemList( items:Array,  index:int ):Array 
		{
			if (items == null || index >= items.length ) 
			{
				return [];
			}
			if (items[ index] is Array) 
			{
				return items[ index ] as Array;
			}
			return [];
		}

		public static function readTuple( ba:ByteArray, template:String ):Array
		{
        	var ch:String = skipWhiteSpace( ba );

        	var item:SVNItem = parseItem(ba, null, ch);
        	if (item.getKind() != SVNItem.LIST) 
        	{
            	//TODO implement error
            	//SVNErrorMessage err = SVNErrorMessage.create(SVNErrorCode.RA_SVN_MALFORMED_DATA);
            	//SVNErrorManager.error(err, SVNLogType.NETWORK);
            	throw new Error( "SVNReader.readTuple() malformed data" );
       		}
       		
        	return parseTupleArray(template, item.getItems(), null);
		}

		public static function parseTupleArray( template:String,  items:Array,  values:Array ):Array
		{
			values = values == null ? new Array() : values;
			parseTuple( template, 0, items, values );
			return values;
		}

		private static function parseTuple( template:String, index:int, items:Array, values:Array):int
		{
        	
        	values = values == null ? new Array() : values;
        	
			for( var i:int = 0; i < items.length && index < template.length ; i++, index++ )
			{
				var item:SVNItem = items[ i ] as SVNItem;
				var ch:String = template.charAt( index );
				
				if( ch == "?" )
				{
					index++;
					ch = template.charAt( index );
				}
        		
				if ((ch == "n" || ch == "r") && item.getKind() == SVNItem.NUMBER) 
				{
					values.push( Number( item.getNumber() ) );
				} 
				else if (ch == "s" && item.getKind( ) == SVNItem.BYTES) 
				{
                
					item.getBytes( ).position = 0;
					values.push( item.getBytes( ).readUTFBytes( item.getBytes( ).bytesAvailable ) );
				} 
				else if (ch == "s" && item.getKind( ) == SVNItem.WORD) 
				{
					values.push( item.getWord( ) );
				} 
				else if (ch == "b" && item.getKind( ) == SVNItem.BYTES) 
				{
					values.push( item.getBytes( ) );
				} 
				else if (ch == "w" && item.getKind( ) == SVNItem.WORD) 
				{
					values.push( item.getWord( ) );
				} 
				else if (ch == "l" && item.getKind( ) == SVNItem.LIST) 
				{
					values.push( item.getItems( ) );
				} 
				else if (ch == "(" && item.getKind( ) == SVNItem.LIST) 
				{
					index++;
					index = parseTuple( template, index, item.getItems( ), values );
				} 
				else if (ch == ")") 
				{
					index++;
					return index;
				} 
				else 
				{
					break;
				}	
			}
       
			if (index < template.length && template.charAt( index ) == "?") 
			{
				var nestingLevel:int = 0;
				while (index < template.length) 
				{
					switch (template.charAt( index )) 
					{
						case "?":
							break;
						case "r":
						case "n":
							values.push( Number( SVNRepository.INVALID_REVISION ) );
							break;
						case "s":
						case "w":
						case "b":
							values.push( null );
							break;
						case "l":
							values.push( [] );
							break;
						case "(":
							nestingLevel++;
							break;
						case ")":
							nestingLevel--;
							if (nestingLevel < 0) 
							{
								return index;
							}
							break;
						default:
							//TODO implement error
							//SVNErrorMessage err = SVNErrorMessage.create(SVNErrorCode.RA_SVN_MALFORMED_DATA);
							// SVNErrorManager.error(err, SVNLogType.NETWORK);
							trace( "parseTuple switch malformed data" );
					}
					index++;
				}
			}
        
			if (index == (template.length - 1) && template.charAt( index ) != ")") 
			{
				//TODO implement error
				//SVNErrorMessage err = SVNErrorMessage.create(SVNErrorCode.RA_SVN_MALFORMED_DATA);
				//SVNErrorManager.error(err, SVNLogType.NETWORK);
				trace( "parseTuple end malformed data" );
			}
			return index;
		}

		private static function parseItem( ba:ByteArray, item:SVNItem, ch:String ):SVNItem
		{
			if (item == null) 
			{
				item = new SVNItem();
			}
        	
			if( Character.isDigit( ch ) ) 
			{
				var value:int = Character.digit(ch, 10);
				
				var previousValue:int;
	            
				while (true) 
				{
					previousValue = value;
					ch = readChar( ba );
                	
					if( Character.isDigit( ch ) ) 
					{
						value = value * 10 + Character.digit(ch, 10);
						if (previousValue != int( value / 10 )) 
						{
							//TODO implement error
							//SVNErrorMessage err = SVNErrorMessage.create(SVNErrorCode.RA_SVN_MALFORMED_DATA, "Number is larger than maximum");
							//SVNErrorManager.error(err, SVNLogType.NETWORK);
							throw new Error( "Number is larger than maximum" );
						}
						continue;
					}
					break;
				}
            	
				//if we are a digit check to see if the next char is a ":"
				if (ch == ":") 
				{
					// string.
					var buffer:ByteArray = new ByteArray();
                	
					try 
					{
						var toRead:int = int( value );

						if( toRead > 0 )
						{
							ba.readBytes( buffer, value - toRead, toRead );
						}
						
					} 
                	catch( e:EOFError ) 
					{
                    	//TODO implement error
                    	//SVNErrorMessage err = SVNErrorMessage.create(SVNErrorCode.RA_SVN_MALFORMED_DATA);
                    	//SVNErrorManager.error(err, SVNLogType.NETWORK);
                    	throw new Error( "MALFORMED DATA" );
					}
                	
					item.setKind( SVNItem.BYTES );
					item.setLine( buffer );

					ch = readChar( ba );
				} 
				else 
				{
					// number.
					item.setKind( SVNItem.NUMBER );
					item.setNumber( value );
				}
			} 
        	else if( Character.isLetter( ch ) ) 
			{
				var stringbuffer:String = "";
            	
				stringbuffer += ch;
				while (true) 
				{
					ch = readChar( ba );
					
					if (Character.isLetterOrDigit( ch ) || ch == '-') 
					{
						stringbuffer += ch;
						continue;
					}
					break;
				}
            	
				item.setKind( SVNItem.WORD );
				item.setWord( stringbuffer );
			} 
       		else if (ch == "(") 
			{
				item.setKind( SVNItem.LIST );
				item.setItems( new Array( ) );
            	
				while (true) 
				{
					ch = skipWhiteSpace( ba );
					if( ch == ")" ) 
					{
						break;
					}
                	
					var child:SVNItem = parseItem( ba, null, ch );
					item.getItems().push( child );
				}
				ch = readChar( ba );

			}
        
			if (!Character.isWhitespace( ch )) 
			{
				//TODO implement ERror
				//SVNErrorMessage err = SVNErrorMessage.create(SVNErrorCode.RA_SVN_MALFORMED_DATA);
				//SVNErrorManager.error(err, SVNLogType.NETWORK);
				throw new Error( "white space malformed data" );
			}
			return item;
		}

		public static function getList( items:Array, index:int ):Array
		{
			
			if( items == null || index >= items.length )
			{
				return( [] );
			}	

			var item:Object = items[ index ];
			
			if( item is Array )
			{
				var list:Array = item as Array;
				for( var i:int = 0; i<list.length; i++ )
				{
					if( list[ i ] is SVNItem )
					{
						var svnItem:SVNItem = list[ i ] as SVNItem;
						if( svnItem.getKind() == SVNItem.BYTES )
						{
							list[ i ] = svnItem.getBytes();	
						}
						else if( svnItem.getKind() == SVNItem.WORD )
						{
							list[ i ] = svnItem.getWord();	
						}
						else if( svnItem.getKind() == SVNItem.NUMBER )
						{
							list[ i ] = svnItem.getNumber();
						}
					}	
				}
				return list;
			}
			
			return [];
		}

		public static function getBoolean( items:Array, index:int ):Boolean 
		{
			if (items == null || index >= items.length) 
			{
				return false;
			}
			
			var item:Object = items[ index ];
			if (item is String) 
			{
				return Boolean( String( item ) );
			}
			return false;
		}

		public static function getString( items:Array, index:int ):String
		{
			if (items == null || index >= items.length) 
			{
				return null;
			}
        
			var item:Object = items[index];
        
			if (item is ByteArray) 
			{
				var ba:ByteArray = item as ByteArray;
				ba.position = 0;
				return ba.readUTFBytes( ba.bytesAvailable );
			} 
        	else if (item is String) 
			{
				return String( item );
			} 
        	else if (item is Number) 
			{
				return item.toString( );
			}
			return null;
		}

		public static function hasValue( items:Array, index:int,  value:Object):Boolean 
		 {
		 	return( false );	
		 }
		 
		  private static function readChar(ba:ByteArray):String
		  {
		  	if( ba.bytesAvailable < 1 )
		  	{
		  		//TODO implement error
		  		throw new Error( "Malformed data" );
		  	}
		  	
		  	var utf:String = ba.readUTFBytes( 1 );
		  	return( utf );
		  }
		 
		 private static function skipWhiteSpace( ba:ByteArray ):String 
		 {
			while (true) 
			{ 
				var ch:String = readChar( ba );
				if( Character.isWhitespace( ch ) ) 
				{
					continue;
				}
				return ch;
			}
			
			return "";
		}
	}
}