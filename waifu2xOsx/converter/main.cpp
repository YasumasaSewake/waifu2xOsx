
#if 0
#include <opencv2/opencv.hpp>
#include <iostream>
#include <sstream>
#include <fstream>
#include <string>
#include <cmath>
#include "picojson.h"
#include "tclap/CmdLine.h"

#include "modelHandler.hpp"
#include "convertRoutine.hpp"

int main(int argc, char** argv) {

	// definition of command line arguments
	TCLAP::CmdLine cmd("waifu2x reimplementation using OpenGL shader", ' ', "1.1.1");

	TCLAP::ValueArg<std::string> cmdInputFile("i", "input_file",
			"path to input image file (you should input full path)", true, "",
			"string", cmd);

	TCLAP::ValueArg<std::string> cmdOutputFile("o", "output_file",
			"path to output image file (you should input full path)", false,
			"(auto)", "string", cmd);

	std::vector<std::string> cmdModeConstraintV;
	cmdModeConstraintV.push_back("noise");
	cmdModeConstraintV.push_back("scale");
	cmdModeConstraintV.push_back("noise_scale");
	TCLAP::ValuesConstraint<std::string> cmdModeConstraint(cmdModeConstraintV);
	TCLAP::ValueArg<std::string> cmdMode("m", "mode", "image processing mode",
			false, "noise_scale", &cmdModeConstraint, cmd);

	std::vector<int> cmdNRLConstraintV;
	cmdNRLConstraintV.push_back(1);
	cmdNRLConstraintV.push_back(2);
	TCLAP::ValuesConstraint<int> cmdNRLConstraint(cmdNRLConstraintV);
	TCLAP::ValueArg<int> cmdNRLevel("", "noise_level", "noise reduction level",
			false, 1, &cmdNRLConstraint, cmd);

	TCLAP::ValueArg<double> cmdScaleRatio("", "scale_ratio",
			"custom scale ratio", false, 2.0, "double", cmd);

	TCLAP::ValueArg<std::string> cmdModelPath("", "model_dir",
			"path to custom model directory (don't append last / )", false,
			"models", "string", cmd);
	
	TCLAP::ValueArg<int> cmdNumberOfJobs("j", "jobs",
			"number of threads launching at the same time (dummy command)", false, 4, "integer",
			cmd);
	
	TCLAP::ValueArg<int> cmdBlockSize("b", "block_size",
			"block size of split processing. default=512", false, 512, "integer",
			cmd);

	// definition of command line argument : end

	// parse command line arguments
	try {
		cmd.parse(argc, argv);
	} catch (std::exception &e) {
		std::cerr << e.what() << std::endl;
		std::cerr << "Error : cmd.parse() threw exception" << std::endl;
		std::exit(-1);
	}

  
  // ここまでコマンドパース（削ること）
  
  // ファイル読み込み
  
	// load image file
	cv::Mat image = cv::imread(cmdInputFile.getValue(), cv::IMREAD_COLOR);
	if (image.size().width == 0 || image.size().height == 0) {
		std::cout << "Error : failed to open " << cmdInputFile.getValue() << std::endl;
		return -1;
	}

  // コンバート処理（ノイズの縮小）
  
	image.convertTo(image, CV_32F, 1.0 / 255.0);

	int blockSize = cmdBlockSize.getValue();
	w2xc::modelUtility::getInstance().setBlockSize(cv::Size(blockSize, blockSize));
	
	// ===== Noise Reduction Phase =====
	if (cmdMode.getValue() == "noise" || cmdMode.getValue() == "noise_scale") {
		
		std::cout << "Noise reduction (Lv." << cmdNRLevel.getValue() << ") filtering..." << std::endl;

		std::string modelFileName(cmdModelPath.getValue());
		modelFileName = modelFileName + "/noise"
				+ std::to_string(cmdNRLevel.getValue()) + "_model.bin";
		std::vector<std::unique_ptr<w2xc::Model> > models;

		if (!w2xc::modelUtility::generateModelFromBin(modelFileName, models))
			std::exit(-1);

		cv::Mat imageYUV;
		cv::cvtColor(image, imageYUV, cv::COLOR_RGB2YUV);
		std::vector<cv::Mat> imageSplit;
		cv::Mat imageY;
		cv::split(imageYUV, imageSplit);
		imageSplit[0].copyTo(imageY);

		w2xc::convertWithModels(imageY, imageSplit[0], models);

		cv::merge(imageSplit, imageYUV);
		cv::cvtColor(imageYUV, image, cv::COLOR_YUV2RGB);

	} // noise reduction phase : end

	// ===== scaling phase =====
  // スケーリング
  
	if (cmdMode.getValue() == "scale" || cmdMode.getValue() == "noise_scale") {

		// calculate iteration times of 2x scaling and shrink ratio which will use at last
		int iterTimesTwiceScaling = static_cast<int>(std::ceil(
				std::log2(cmdScaleRatio.getValue())));
		double shrinkRatio = 0.0;
		if (static_cast<int>(cmdScaleRatio.getValue())
				!= std::pow(2, iterTimesTwiceScaling)) {
			shrinkRatio = cmdScaleRatio.getValue()
					/ std::pow(2.0, static_cast<double>(iterTimesTwiceScaling));
		}

		std::string modelFileName(cmdModelPath.getValue());
		modelFileName = modelFileName + "/scale2.0x_model.bin";
		std::vector<std::unique_ptr<w2xc::Model> > models;

		if (!w2xc::modelUtility::generateModelFromBin(modelFileName, models))
			std::exit(-1);

		// 2x scaling
		for (int nIteration = 0; nIteration < iterTimesTwiceScaling;
				nIteration++) {

			std::cout << "#" << std::to_string(nIteration + 1)
					<< " 2x Scaling..." << std::endl;

			cv::Mat imageYUV;
			cv::Size imageSize = image.size();
			imageSize.width *= 2;
			imageSize.height *= 2;
			cv::Mat image2xNearest;
			cv::resize(image, image2xNearest, imageSize, 0, 0, cv::INTER_NEAREST);
			cv::cvtColor(image2xNearest, imageYUV, cv::COLOR_RGB2YUV);
			std::vector<cv::Mat> imageSplit;
			cv::Mat imageY;
			cv::split(imageYUV, imageSplit);
			imageSplit[0].copyTo(imageY);

			// generate bicubic scaled image and
			// convert RGB -> YUV and split
			imageSplit.clear();
			cv::Mat image2xBicubic;
			cv::resize(image,image2xBicubic,imageSize,0,0,cv::INTER_CUBIC);
			cv::cvtColor(image2xBicubic, imageYUV, cv::COLOR_RGB2YUV);
			cv::split(imageYUV, imageSplit);

			if(!w2xc::convertWithModels(imageY, imageSplit[0], models)){
				std::cerr << "w2xc::convertWithModels : something error has occured.\n"
						"stop." << std::endl;
				std::exit(1);
			};

			cv::merge(imageSplit, imageYUV);
			cv::cvtColor(imageYUV, image, cv::COLOR_YUV2RGB);

		} // 2x scaling : end

		if (shrinkRatio != 0.0) {
			cv::Size lastImageSize = image.size();
			lastImageSize.width =
					static_cast<int>(static_cast<double>(lastImageSize.width
							* shrinkRatio));
			lastImageSize.height =
					static_cast<int>(static_cast<double>(lastImageSize.height
							* shrinkRatio));
			cv::resize(image, image, lastImageSize, 0, 0, cv::INTER_LINEAR);
		}

	}

	image.convertTo(image, CV_8U, 255.0);
  
  // ファイル名の決定と書き込み
  
	std::string outputFileName = cmdOutputFile.getValue();
	if (outputFileName == "(auto)") {
		outputFileName = cmdInputFile.getValue();
		int tailDot = outputFileName.find_last_of('.');
		outputFileName.erase(tailDot, outputFileName.length());
		outputFileName = outputFileName + "(" + cmdMode.getValue() + ")";
		std::string &mode = cmdMode.getValue();
		if(mode.find("noise") != mode.npos){
			outputFileName = outputFileName + "(Level" + std::to_string(cmdNRLevel.getValue())
			+ ")";
		}
		if(mode.find("scale") != mode.npos){
			outputFileName = outputFileName + "(x" + std::to_string(cmdScaleRatio.getValue())
			+ ")";
		}
		outputFileName += ".png";
	}
	cv::imwrite(outputFileName, image);

	std::cout << "process successfully done!" << std::endl;

	return 0;
}
#endif
