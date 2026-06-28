import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = LivePhotoViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Шапка
                VStack(spacing: 8) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("DiWall")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Живые обои из любого видео")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Кнопка выбора видео
                PhotosPicker(
                    selection: $viewModel.selectedVideo,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Label(
                        viewModel.selectedVideo == nil ? "Выбрать видео" : "Видео выбрано ✅",
                        systemImage: viewModel.selectedVideo == nil ? "video.badge.plus" : "checkmark.circle"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedVideo == nil ? Color.blue : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Информация о выбранном видео
                if viewModel.selectedVideo != nil {
                    HStack {
                        Image(systemName: "video.fill")
                        Text("Видео загружено")
                            .font(.caption)
                        Spacer()
                        Button("Очистить") {
                            viewModel.selectedVideo = nil
                            viewModel.statusMessage = ""
                            viewModel.isGenerating = false
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
                
                // Кнопка создания Live Photo
                Button(action: {
                    viewModel.generateLivePhoto()
                }) {
                    HStack {
                        if viewModel.isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 4)
                        }
                        Text(viewModel.isGenerating ? "Создание..." : "Создать Live Photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedVideo == nil || viewModel.isGenerating ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.selectedVideo == nil || viewModel.isGenerating)
                
                // Статус и инструкция
                if !viewModel.statusMessage.isEmpty {
                    ScrollView {
                        Text(viewModel.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 200)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}
