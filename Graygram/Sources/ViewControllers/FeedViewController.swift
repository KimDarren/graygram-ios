//
//  FeedViewController.swift
//  Graygram
//
//  Created by Suyeol Jeon on 05/02/2017.
//  Copyright © 2017 Suyeol Jeon. All rights reserved.
//

import UIKit
import Alamofire

final class FeedViewController: UIViewController {

  // MARK: Properties

  fileprivate var posts: [Post] = []
  fileprivate var nextURLString: String?
  fileprivate var isLoading: Bool = false


  // MARK: UI

  fileprivate let refreshControl = UIRefreshControl()
  fileprivate let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout()).then {
    $0.backgroundColor = .white
    $0.register(PostCardCell.self, forCellWithReuseIdentifier: "cardCell")
    $0.register(
      CollectionActivityIndicatorView.self,
      forSupplementaryViewOfKind: UICollectionElementKindSectionFooter,
      withReuseIdentifier: "activityIndicatorView"
    )
  }


  // MARK: View Life Cycle

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.titleView = UILabel().then {
      $0.font = UIFont(name: "IowanOldStyle-BoldItalic", size: 20)
      $0.text = "Graygram"
      $0.sizeToFit()
    }

    self.collectionView.dataSource = self
    self.collectionView.delegate = self

    self.refreshControl.addTarget(self, action: #selector(self.refreshControlDidChangeValue), for: .valueChanged)

    NotificationCenter.default.addObserver(self, selector: #selector(postDidLike), name: .postDidLike, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(postDidUnlike), name: .postDidUnlike, object: nil)

    self.collectionView.addSubview(self.refreshControl)
    self.view.addSubview(self.collectionView)

    self.collectionView.snp.makeConstraints { make in
      make.edges.equalToSuperview()
    }

    self.fetchPosts()
  }

  // MARK: Networking

  fileprivate func fetchPosts(more: Bool = false) {
    guard !self.isLoading else { return }

    let urlString: String
    if !more {
      urlString = "https://api.graygram.com/feed?limit=10"
    } else if let nextURLString = self.nextURLString {
      urlString = nextURLString
    } else {
      return
    }

    self.isLoading = true

    Alamofire.request(urlString).responseJSON { [weak self] response in
      guard let `self` = self else { return }
      self.refreshControl.endRefreshing()
      self.isLoading = false

      switch response.result {
      case .success(let value):
        guard let json = value as? [String: Any] else { return }
        let postsJSONArray = json["data"] as? [[String: Any]] ?? []
        let newPosts = [Post](JSONArray: postsJSONArray) ?? []

        if !more {
          self.posts = newPosts
        } else {
          self.posts.append(contentsOf: newPosts)
        }

        let paging = json["paging"] as? [String: Any]
        self.nextURLString = paging?["next"] as? String

        self.collectionView.reloadData()

      case .failure(let error):
        print(error)
      }
    }
  }


  // MARK: Actions

  fileprivate dynamic func refreshControlDidChangeValue() {
    self.fetchPosts()
  }


  // MARK: Notifications

  func postDidLike(_ notification: Notification) {
    guard let postID = notification.userInfo?["postID"] as? Int else { return }
    for (i, var post) in self.posts.enumerated() {
      if post.id == postID {
        post.likeCount! += 1
        post.isLiked = true
        self.posts[i] = post
        self.collectionView.reloadData()
        break
      }
    }
  }

  func postDidUnlike(_ notification: Notification) {
    guard let postID = notification.userInfo?["postID"] as? Int else { return }
    for (i, var post) in self.posts.enumerated() {
      if post.id == postID {
        post.likeCount! = max(0, post.likeCount! - 1)
        post.isLiked = false
        self.posts[i] = post
        self.collectionView.reloadData()
        break
      }
    }
  }

}


// MARK: - UICollectionViewDataSource

extension FeedViewController: UICollectionViewDataSource {

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.posts.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cardCell", for: indexPath) as! PostCardCell
    cell.configure(post: self.posts[indexPath.item])
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    let isLastSection = indexPath.section == collectionView.numberOfSections - 1
    let isFooter = kind == UICollectionElementKindSectionFooter
    if isLastSection && isFooter {
      return collectionView.dequeueReusableSupplementaryView(
        ofKind: kind,
        withReuseIdentifier: "activityIndicatorView",
        for: indexPath
      )
    }
    return UICollectionReusableView()
  }

}


// MARK: - UICollectionViewDelegateFlowLayout

extension FeedViewController: UICollectionViewDelegateFlowLayout {

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let cellWidth = collectionView.frame.width
    return PostCardCell.size(width: cellWidth, post: self.posts[indexPath.item])
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 20
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let contentOffsetBottom = scrollView.contentOffset.y + scrollView.height
    if scrollView.contentSize.height > 0 && contentOffsetBottom >= scrollView.contentSize.height - 300 {
      self.fetchPosts(more: true)
    }
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
    let height: CGFloat = self.nextURLString != nil ? 44 : 0
    return CGSize(width: collectionView.width, height: height)
  }

}
