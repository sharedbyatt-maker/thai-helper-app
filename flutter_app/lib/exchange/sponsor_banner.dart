import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'rates_repository.dart';

/// Optional, fail-closed sponsor placement. Private money data is never read
/// or sent to this endpoint. No third-party impression tracking is attached.
class SponsorBanner extends StatefulWidget {
  final String placement;
  final String? apiBase;
  final http.Client? client;
  const SponsorBanner({super.key,required this.placement,this.apiBase,this.client});
  @override
  State<SponsorBanner> createState()=>_SponsorBannerState();
}
class _SponsorBannerState extends State<SponsorBanner> {
  Map<String,dynamic>? sponsor;
  String get platform => kIsWeb?'web':switch(defaultTargetPlatform){
    TargetPlatform.android=>'android',TargetPlatform.iOS=>'ios',_=>'web',
  };
  bool safeUrl(String raw) {
    final url=Uri.tryParse(raw);
    return url!=null&&url.scheme=='https'&&url.host.isNotEmpty&&url.userInfo.isEmpty;
  }
  @override
  void initState(){super.initState();fetch();}
  Future<void> fetch() async {
    final base=widget.apiBase??RatesRepository.apiBase;
    final endpoint=base.isEmpty?Uri.base.resolve('/api/v2/ads'):Uri.parse('$base/api/v2/ads');
    final client=widget.client??http.Client();
    try{
      final response=await client.get(endpoint).timeout(const Duration(seconds:4));
      if(response.statusCode!=200)return;
      final json=jsonDecode(response.body);
      if(json is! Map<String,dynamic>||json['enabled']!=true||
         json['platforms'] is! Map||json['platforms'][platform]!=true||
         json['placements'] is! Map||json['placements'][widget.placement]!=true||
         json['sponsors'] is! List)return;
      if(!mounted)return;
      final language=Localizations.localeOf(context).languageCode;
      for(final candidate in json['sponsors'] as List){
        if(candidate is! Map||candidate['placements'] is! List||
           !(candidate['placements'] as List).contains(widget.placement))continue;
        if(candidate['language']!='both'&&candidate['language']!=language)continue;
        final name=candidate['name'],image=candidate['image_url'],target=candidate['destination_url'];
        if(name is! String||image is! String||target is! String||
           !safeUrl(image)||!safeUrl(target))continue;
        setState(()=>sponsor=Map<String,dynamic>.from(candidate));
        break;
      }
    }catch(_){
      // The user view must remain usable when sponsor API is unavailable.
    }finally{if(widget.client==null)client.close();}
  }
  @override
  Widget build(BuildContext context){
    final ad=sponsor;
    if(ad==null)return const SizedBox.shrink();
    final english=Localizations.localeOf(context).languageCode=='en';
    return Padding(
      key:ValueKey('sponsor_'+widget.placement),
      padding:const EdgeInsets.symmetric(vertical:12),
      child:Card(
        color:Theme.of(context).colorScheme.surfaceContainerLow,
        clipBehavior:Clip.antiAlias,
        child:Padding(
          padding:const EdgeInsets.all(14),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(english?'Sponsored':'ကြော်ငြာ / Sponsored',
              style:Theme.of(context).textTheme.labelSmall),
            const SizedBox(height:8),
            Row(children:[
              ClipRRect(
                borderRadius:BorderRadius.circular(10),
                child:Image.network(ad['image_url'] as String,width:72,height:72,
                  fit:BoxFit.cover,errorBuilder:(_,error,stack)=>
                    const SizedBox(width:72,height:72,child:Icon(Icons.storefront_outlined))),
              ),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(ad['name'] as String,style:Theme.of(context).textTheme.titleSmall),
                if((ad['label'] as String? ?? '').isNotEmpty)
                  Text(ad['label'] as String,maxLines:2,overflow:TextOverflow.ellipsis),
              ])),
            ]),
            Align(alignment:Alignment.centerRight,child:TextButton.icon(
              key:ValueKey('sponsor_link_'+widget.placement),
              onPressed:() async {
                final raw=ad['destination_url'] as String;
                if(!safeUrl(raw))return;
                try{await launchUrl(Uri.parse(raw),mode:LaunchMode.externalApplication);}catch(_){}
              },
              icon:const Icon(Icons.open_in_new,size:17),
              label:Text(english?'Visit sponsor':'Sponsor ထံသို့သွားမယ်'),
            )),
          ]),
        ),
      ),
    );
  }
}
