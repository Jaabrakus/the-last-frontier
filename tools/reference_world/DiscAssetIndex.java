/* Offline inspection bridge to JWUDTool/JNUSLib. Keys arrive on stdin, never in argv or records. */
import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.util.regex.*;
import de.mas.wiiu.jnus.WUDLoader;
import de.mas.wiiu.jnus.interfaces.FSTDataProvider;
import de.mas.wiiu.jnus.entities.FST.nodeentry.*;

public class DiscAssetIndex {
 static String quote(String s) {
  StringBuilder b=new StringBuilder("\"");
  for(char c:s.toCharArray()) {
   switch(c) {case '"':b.append("\\\"");break;case '\\':b.append("\\\\");break;case '\n':b.append("\\n");break;case '\r':b.append("\\r");break;case '\t':b.append("\\t");break;
    default:if(c<32)b.append(String.format("\\u%04x",(int)c));else b.append(c);}
  }
  return b.append('"').toString();
 }
 public static void main(String[] args) throws Exception {
  if(args.length<2)throw new IllegalArgumentException("Image path and output directory required; optional file regex");
  byte[] input=System.in.readNBytes(32);
  if(input.length!=32)throw new IllegalArgumentException("Expected disc and common key bytes on stdin");
  byte[] discKey=Arrays.copyOfRange(input,0,16),commonKey=Arrays.copyOfRange(input,16,32);
  Path out=Paths.get(args[1]).toAbsolutePath();Files.createDirectories(out);
  Pattern pattern=args.length>2?Pattern.compile(args[2]):null;
  var disc=WUDLoader.load(args[0],discKey);
  System.out.println("Disc headers and partition filesystem parsed.");
  var providers=WUDLoader.getPartitonsAsFSTDataProvider(disc,commonKey);
  List<String> rows=new ArrayList<>(), exported=new ArrayList<>();
  long bytes=0;int count=0;
  for(FSTDataProvider provider:providers) {
   String name=provider.getName();
   var nodes=provider.getRoot().stream().filter(NodeEntry::isFile).toList();
   System.out.println("Partition "+name+": "+nodes.size()+" files");
   for(NodeEntry node:nodes) {
    FileEntry file=(FileEntry)node;
    String path=file.getFullPath();
    rows.add("{\"partition\":"+quote(name)+",\"path\":"+quote(path)+",\"bytes\":"+file.getSize()+"}");
    if(pattern==null||!pattern.matcher(path).matches())continue;
    if(file.getSize()>1024L*1024*1024)throw new IOException("Selected member exceeds 1 GiB cap");
    if(Files.getFileStore(out).getUsableSpace()<file.getSize()+2L*1024*1024*1024)throw new IOException("Disk reserve insufficient");
    String rel=path.replaceFirst("^/+","");
    Path partition=out.resolve("files").resolve(name.replaceAll("[^a-zA-Z0-9_.-]","_"));
    Path target=partition.resolve(rel).normalize();
    if(!target.startsWith(partition))throw new IOException("Unsafe source path");
    Files.createDirectories(target.getParent());
    MessageDigest digest=MessageDigest.getInstance("SHA-256");
    Path temp=Files.createTempFile(target.getParent(),target.getFileName()+".",".partial");
    try {
     long written;
     try(OutputStream stream=new DigestOutputStream(Files.newOutputStream(temp),digest)) {written=provider.readFileToStream(stream,file);}
     if(written!=file.getSize()||Files.size(temp)!=file.getSize())throw new IOException("Short extraction: "+path);
     // Force durability before exposing a complete-looking file.
     try(var channel=java.nio.channels.FileChannel.open(temp,StandardOpenOption.WRITE)){channel.force(true);}
     Files.move(temp,target);
     String hash=HexFormat.of().formatHex(digest.digest());
     exported.add("{\"partition\":"+quote(name)+",\"source_path\":"+quote(path)+",\"file\":"+quote(out.relativize(target).toString())+",\"bytes\":"+written+",\"sha256\":"+quote(hash)+"}");
     bytes+=written;count++;
     System.out.println("Extracted "+path+" ("+written+" bytes)");
    } finally {Files.deleteIfExists(temp);}
   }
  }
  Files.writeString(out.resolve("disc_catalogue.json"),"["+String.join(",\n",rows)+"]\n");
  Files.writeString(out.resolve("export_manifest.json"),"["+String.join(",\n",exported)+"]\n");
  System.out.println("Indexed "+rows.size()+" files; exported "+count+" files / "+bytes+" bytes.");
  Arrays.fill(input,(byte)0);Arrays.fill(discKey,(byte)0);Arrays.fill(commonKey,(byte)0);
 }
}
