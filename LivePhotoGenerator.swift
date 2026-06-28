import SwiftUI
import AVFoundation
import Photos
import PhotosUI
import UniformTypeIdentifiers

class LivePhotoViewModel: ObservableObject {
    @Published var selectedVideo: PhotosPickerItem? {
        didSet {
            loadVideo()
        }
    }
    @Published var isGenerating = false
    @Published var statusMessage = ""
    
    private var videoURL: URL?
    private var trimmedVideoURL: URL?
    private var thumbnailURL: URL?
    
    // Загрузка видео из PhotosPicker
    private func loadVideo() {
        guard let item = selectedVideo else { return }
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let data = data else { return }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                    try? data.write(to: tempURL)
                    self.videoURL = tempURL
                    self.statusMessage = "✅ Видео загружено, можно создавать Live Photo"
                case .failure(let error):
                    self.statusMessage = "❌ Ошибка загрузки: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Основной метод генерации Live Photo
    func generateLivePhoto() {
        guard let videoURL = videoURL else {
            statusMessage = "❌ Сначала выберите видео"
            return
        }
        
        // Проверяем доступ к галерее
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status != .authorized && status != .limited {
                    self.statusMessage = "❌ Нет доступа к галерее. Разрешите доступ в настройках."
                    return
                }
                self.startGeneration(videoURL: videoURL)
            }
        }
    }
    
    private func startGeneration(videoURL: URL) {
        isGenerating = true
        statusMessage = "⏳ Обработка видео..."
        
        // 1. Обрезаем видео до 3 секунд
        trimVideo(videoURL: videoURL) { trimmedURL in
            guard let trimmedURL = trimmedURL else {
                DispatchQueue.main.async {
                    self.statusMessage = "❌ Ошибка обрезки видео"
                    self.isGenerating = false
                }
                return
            }
            self.trimmedVideoURL = trimmedURL
            
            // 2. Извлекаем первый кадр как обложку
            let thumbnailURL = self.extractThumbnail(from: trimmedURL)
            self.thumbnailURL = thumbnailURL
            
            // 3. Сохраняем Live Photo в галерею
            self.saveLivePhotoToLibrary(videoURL: trimmedURL, thumbnailURL: thumbnailURL)
        }
    }
    
    // Обрезка видео до 3 секунд
    private func trimVideo(videoURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration.seconds
        let trimDuration = min(3.0, duration)
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        // Удаляем старый файл, если есть
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil)
            return
        }
        
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: trimDuration, preferredTimescale: 600))
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                completion(outputURL)
            } else {
                completion(nil)
            }
        }
    }
    
    // Извлечение первого кадра
    private func extractThumbnail(from videoURL: URL) -> URL {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            fatalError("Не удалось извлечь кадр")
        }
        
        let thumbnailURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.9) else {
            fatalError("Не удалось сохранить кадр")
        }
        
        try? data.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    // Сохранение файлов как Live Photo в галерею
    private func saveLivePhotoToLibrary(videoURL: URL, thumbnailURL: URL) {
        // Проверяем, что файлы существуют
        guard FileManager.default.fileExists(atPath: videoURL.path),
              FileManager.default.fileExists(atPath: thumbnailURL.path) else {
            DispatchQueue.main.async {
                self.statusMessage = "❌ Ошибка: файлы не найдены"
                self.isGenerating = false
            }
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            
            // Добавляем фото
            creationRequest.addResource(with: .photo, fileURL: thumbnailURL, options: options)
            
            // Добавляем видео как парный ресурс (Live Photo)
            creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: options)
            
        }) { success, error in
            DispatchQueue.main.async {
                self.isGenerating = false
                if success {
                    self.statusMessage = """
                    ✅ Live Photo сохранено в галерею!
                    
                    📱 Как установить на экран блокировки:
                    1. Открой приложение «Фото»
                    2. Найди свежее Live Photo (в альбоме «Недавние»)
                    3. Нажми на него, чтобы открыть
                    4. Нажми кнопку «Поделиться» (квадрат со стрелкой)
                    5. Выбери «Использовать как обои»
                    6. Нажми «Добавить» → «Установить как пару обоев»
                    
                    💡 Готово! Теперь при нажатии на экран блокировки — видео оживёт.
                    """
                } else {
                    self.statusMessage = "❌ Ошибка сохранения: \(error?.localizedDescription ?? "Неизвестная ошибка")"
                }
            }
        }
    }
}