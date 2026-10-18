/* Offline bounded SARC-name scan. Source keys arrive only on stdin. */
import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import de.mas.wiiu.jnus.WUDLoader;
import de.mas.wiiu.jnus.interfaces.FSTDataProvider;
import de.mas.wiiu.jnus.entities.FST.nodeentry.*;

public class DiscPackHeaderScan {
    static final int LIMIT=1024*1024;
    static String quote(String s) {
        StringBuilder b=new StringBuilder("\"");
        for(char c:s.toCharArray()) {
            switch(c) { case '"': b.append("\\\"");break; case '\\':b.append("\\\\");break;
                case '\n':b.append("\\n");break;case '\r':b.append("\\r");break;case '\t':b.append("\\t");break;
                default:if(c<32)b.append(String.format("\\u%04x",(int)c));else b.append(c); }
        }
        return b.append('"').toString();
    }
    static byte[] prefix(FSTDataProvider provider,FileEntry file,int length) throws IOException {
        ByteArrayOutputStream stream=new ByteArrayOutputStream(length);
        long written=provider.readFileToStream(stream,file,0L,(long)length);
        byte[] result=stream.toByteArray();
        if(written!=length||result.length!=length)throw new IOException("Short prefix read: "+file.getFullPath());
        return result;
    }
    public static void main(String[] args) throws Exception {
        if(args.length!=2)throw new IllegalArgumentException("Usage: DiscPackHeaderScan verified.wux output-directory; 32 key bytes on stdin");
        byte[] keyBytes=System.in.readNBytes(32);
        if(keyBytes.length!=32)throw new IllegalArgumentException("Expected disc and common key bytes");
        byte[] discKey=Arrays.copyOfRange(keyBytes,0,16),commonKey=Arrays.copyOfRange(keyBytes,16,32);
        try {
            Path output=Paths.get(args[1]).toAbsolutePath();Files.createDirectories(output);
            var disc=WUDLoader.load(args[0],discKey);
            var providers=WUDLoader.getPartitonsAsFSTDataProvider(disc,commonKey);
            List<String> rows=new ArrayList<>();int count=0;long readBytes=0;int links=0;
            for(FSTDataProvider provider:providers) {
                for(NodeEntry node:provider.getRoot().stream().filter(NodeEntry::isFile).toList()) {
                    FileEntry file=(FileEntry)node;String path=file.getFullPath();
                    if(!path.startsWith("/content/Pack/")||!path.endsWith(".pack"))continue;
                    if(file.getSize()<20)throw new IOException("Pack is too short");
                    byte[] header=prefix(provider,file,(int)Math.min(32,file.getSize()));
                    boolean sarc=header[0]=='S'&&header[1]=='A'&&header[2]=='R'&&header[3]=='C';
                    if(sarc) {
                        ByteOrder order=(header[6]==(byte)0xfe&&header[7]==(byte)0xff)?ByteOrder.BIG_ENDIAN:
                            (header[6]==(byte)0xff&&header[7]==(byte)0xfe)?ByteOrder.LITTLE_ENDIAN:null;
                        if(order==null)throw new IOException("Bad SARC byte order");
                        ByteBuffer buffer=ByteBuffer.wrap(header).order(order);
                        long length=Integer.toUnsignedLong(buffer.getInt(8));
                        long dataStart=Integer.toUnsignedLong(buffer.getInt(12));
                        if(length!=file.getSize()||dataStart<20||dataStart>LIMIT||dataStart>length)
                            throw new IOException("Invalid or oversized pack-name prefix: "+path);
                        header=prefix(provider,file,(int)dataStart);
                    }
                    String partition=provider.getName().replaceAll("[^a-zA-Z0-9_.-]","_");
                    Path target=output.resolve("headers").resolve(partition).resolve(path.substring("/content/Pack/".length())+".header");
                    Files.createDirectories(target.getParent());
                    Files.write(target,header,StandardOpenOption.CREATE_NEW);
                    String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(header));
                    rows.add("{\"partition\":"+quote(provider.getName())+",\"source_path\":"+quote(path)+
                        ",\"source_bytes\":"+file.getSize()+",\"is_link\":"+file.isLink()+",\"is_sarc\":"+sarc+
                        ",\"header_file\":"+quote(output.relativize(target).toString())+",\"header_bytes\":"+header.length+
                        ",\"header_sha256\":"+quote(hash)+"}");
                    count++;readBytes+=header.length;if(file.isLink())links++;
                }
            }
            String manifest="{\"source_image\":"+quote(Paths.get(args[0]).toAbsolutePath().toString())+
                ",\"scope\":\"Every top-level /content/Pack/*.pack file in every disc FST provider; SARC header/name table only.\",\"maximum_prefix_bytes\":"+LIMIT+
                ",\"packs\":["+String.join(",\n",rows)+"]}\n";
            Files.writeString(output.resolve("pack_headers.json"),manifest,StandardOpenOption.CREATE_NEW);
            System.out.println("Read bounded names from "+count+" packs, "+readBytes+" bytes; linked packs: "+links);
        } finally {Arrays.fill(keyBytes,(byte)0);Arrays.fill(discKey,(byte)0);Arrays.fill(commonKey,(byte)0);}
    }
}
