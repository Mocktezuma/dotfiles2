# module for parsing frames out of extended format pcap files
# as the format is defined at http://www.winpcap.org/ntar/draft/PCAP-DumpFileFormat.html


package extendedPCAP;

use strict;

use vars qw($version @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qr(Exporter Autoloader);

@EXPORT = qw(PCAP_IP_Extract);
$version = '0.01';


# state variables

my %FLAG = (
    
    "BIG_ENDIAN" => 0,
 
    );

# reference variables

my %NETWORK_PROTOCOL =(
    
    "08" => "IP",
    
    );

my %TRANSPORT_PROTOCOL = (
    
    "06" => "TCP",
    "11" => "UDP",

    );

# globals

my $SHB = 0x0a0d0d0a; # section header block (SHB)
my $IDB = 0x00000001; # interface description block (IDB)
my $EPB = 0x00000006; # enhanced packet block (EPB)
my $SPB = 0x00000003; # simple packet block (SPB)

sub Parse {

    my $source_data_array_ref = shift;                     # in from a scalar pointer
    my @frame_bucket = ();                                 # out to an array containing each parsed frame

    my $count = 1;

    # at this point we may assume that we are at start of file beginning with the first Section Header Block (SHB)

    print "extended pcap format!\n";

    while (length($$source_data_array_ref) > 0) {
    
	ParseBlock($source_data_array_ref);

	my $pcap_frame_preamble = PCAP_Frame_Preamble($source_data_array_ref);

	my $pcap_frame_length = PCAP_Frame_Size($pcap_frame_preamble);

	my $frame_contents = PCAP_Frame_Contents($source_data_array_ref,$pcap_frame_length);
	
	push @frame_bucket,$frame_contents;

    }   
 
    return \@frame_bucket;

}



sub Identify_PCAP_File_Format {             # check whether header has the magic bytes for .pcap

    my $pcap_file_data = shift;

    use bytes;

    (my $pcap_file_header) = $$pcap_file_data =~ /(^.{24})/s;             # first 24 bytes of PCAP file

    (my $magic_bytes) = $pcap_file_header =~ /(^.{4})/s;

    my $magic_ascii = unpack("H32",$magic_bytes);

    if ($magic_ascii =~ /d4c3b2a1/) {          # classic pcap file format

	$$pcap_file_data =~ s/^.{24}//s;       

    } 

    elsif ($magic_ascii =~ /0a0d0d0a/) { # extended pcap file format simple header block identifier

	extendedPCAP::Parse($pcap_file_data);    # pass to another module to handle extended "next gen" pcap format

    }

    else {

	die "uncecognized pcap file format\n";

    }

}

sub PCAP_Frame_Preamble {                   # parse metadata preceding each frame, grabbing length of frame
    my $pcap_file_data = shift;

    use bytes;
    
    (my $pcap_packet_preamble) = $$pcap_file_data =~ /(^.{16})/s;          # 16 bytes of packet metadata used by PCAP file precede each actual packet data
    
    $$pcap_file_data =~ s/^.{16}//s;

    return $pcap_packet_preamble;
}

sub PCAP_Frame_Size {                          # return  size of proceeding packet from preamble information
    my $preamble = shift;

    use bytes;

    (my $packet_size) = $preamble =~ /(.{4}).{4}$/s; # the actual # of packets saved to file

    my $packet_size = unpack("H8",$packet_size);
 
    return unpack ("I",pack("H8",$packet_size));    
}

sub PCAP_Frame_Contents {
    my $pcap_file_data = shift;
    my $length = shift;

    my $frame_block = qr/(^.{$length})/s;

    use bytes;

    (my $pcap_frame_contents) = $$pcap_file_data =~ /$frame_block/;

    $$pcap_file_data =~ s/$frame_block//s;

    return $pcap_frame_contents;
}


sub ParseBlock {
    
    my $data = shift;

    my $block = IdentifyBlock($data);         # return block metadata depending on type of block

    $block = GetBlockInfo($block,$data);      # parse the block info and remove block from file

    if ($block->{type} eq $SHB) {

	die "SHB detected!\n";

    }
}

sub IdentifyBlock {

    my $data_ref = shift;
    
    use bytes;

    (
    
     my $blockType,
     my $blockLength
    
    ) = $$data_ref=~ /
                    (^.{4})  # block type always come first
                    (.{4})  # block length always comes second
                  .*?$
                  /sx;

    my %BlockInfo = (

	# general to EPB,SPB,IDB,SHB

	"type"     => binman::Packed($blockType),    # block type
	"length" => $blockLength,                    # block total length
	"options"  => 0,                             # pointer to options	(won't be filled until later though)

	);

    return \%BlockInfo;

}


sub GetBlockInfo {
    
    my $block = shift;
    my $data = shift;

    if ($block->{type} eq $SHB) {
	
	ParseSHB($block,$data);
	
    }

    else {

	die sprintf("unrecognized block of type 0x%X!\n",$block->{type});

    }

}

sub ParseSHB {

    my $block = shift;
    my $data  = shift;

    myIO::PrintBytes($block->{length});

    die sprintf("SHB block length %d bytes\n",binman::Packed_DWORD($block->{length}));

}
