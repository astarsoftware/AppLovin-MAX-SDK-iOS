//
//  MolocoAdapter+Native.swift
//  MolocoAdapter
//
//  Created by Alan Cao on 2/28/24.
//  Copyright © 2024 AppLovin. All rights reserved.
//

import AppLovinSDK
import MolocoSDK

extension MolocoAdapter: MANativeAdAdapter
{
    func loadNativeAd(for parameters: MAAdapterResponseParameters, andNotify delegate: MANativeAdAdapterDelegate)
    {
        let placementId = parameters.thirdPartyAdPlacementIdentifier
        
        log(adEvent: .loading(), id: placementId, adFormat: .native)
        
        updatePrivacyStates(for: parameters)
        
        Task {
            nativeAdDelegate = .init(adapter: self, delegate: delegate, parameters: parameters)
            nativeAd = await Moloco.shared.createNativeAd(for: placementId, delegate: nativeAdDelegate)
            guard let nativeAd else
            {
                log(adEvent: .loadFailed(error: .invalidConfiguration), adFormat: .native)
                delegate.didFailToLoadNativeAdWithError(.invalidConfiguration)
                return
            }
            
            await nativeAd.load(bidResponse: parameters.bidResponse)
        }
    }
}

final class MolocoNativeAdapterDelegate: NativeAdAdapterDelegate<MolocoAdapter>, MolocoNativeAdDelegate
{
    func didLoad(ad: MolocoAd)
    {
        guard let nativeAd = adapter.nativeAd else
        {
            logError("[\(adIdentifier)] Native ad is nil")
            delegate?.didFailToLoadNativeAdWithError(.invalidConfiguration)
            return
        }
        
        guard nativeAd.isReady else
        {
            adapter.log(adEvent: .notReady, adFormat: adFormat)
            delegate?.didFailToLoadNativeAdWithError(.adNotReady)
            return
        }
        
        log(adEvent: .loaded)
        
        guard let assets = nativeAd.assets, !assets.title.isEmpty else
        {
            log(adEvent: .missingRequiredAssets)
            delegate?.didFailToLoadNativeAdWithError(.missingRequiredNativeAdAssets)
            return
        }
        
        nativeAd.show(in: ALUtils.topViewControllerFromKeyWindow())
                                
        let maxNativeAd = MAMolocoNativeAd(adapter: adapter, adFormat: adFormat) { builder in
            builder.title = assets.title
            builder.body = assets.description
            builder.advertiser = assets.sponsorText
            builder.callToAction = assets.ctaTitle
            builder.icon = assets.appIcon.map { .init(image: $0) }
            builder.starRating = assets.rating as NSNumber
            builder.mediaView = assets.videoView ?? UIImageView(image: assets.mainImage)
            builder.mainImage = assets.mainImage.map { .init(image: $0) }
        }
        
        delegate?.didLoadAd(for: maxNativeAd, withExtraInfo: nil)
    }
    
    func failToLoad(ad: MolocoAd, with error: Error?)
    {
        let adapterError = error?.molocoNativeAdapterError ?? error?.molocoAdapterError ?? .unspecified
        log(adEvent: .loadFailed(error: adapterError))
        delegate?.didFailToLoadNativeAdWithError(adapterError)
    }
    
    func didShow(ad: MolocoAd)
    {
        log(adEvent: .displayed)
        delegate?.didDisplayNativeAd(withExtraInfo: nil)
    }
    
    func failToShow(ad: MolocoAd, with error: Error?)
    {
        let adapterError = error?.molocoNativeAdapterError ?? error?.molocoAdapterError ?? .unspecified
        log(adEvent: .displayFailed(error: adapterError))
    }
    
    func didClick(on ad: MolocoAd)
    {
        log(adEvent: .clicked)
        delegate?.didClickNativeAd()
    }
    
    func didHide(ad: MolocoAd)
    {
        log(adEvent: .hidden)
    }
}
